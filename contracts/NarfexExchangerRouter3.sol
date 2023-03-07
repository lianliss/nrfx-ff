//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import './PancakeLibrary.sol';
import './INarfexOracle.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface INarfexFiat is IERC20 {
    function burnFrom(address _address, uint _amount) external;
    function mintTo(address _address, uint _amount) external;
}

interface INarfexExchangerPool {
    function getFeeAmount() external view returns (uint);
    function getBalance() external view returns (uint);
    function approveRouter() external;
    function increaseLimit(address _validator, address _fiatAddress, uint _amount) external;
    function decreaseLimit(address _validator, address _fiatAddress, uint _amount) external;
    function increaseFeeAmount(uint _amount) external;
    function clearFeeAmount() external;
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

/// @title DEX Router for Narfex Fiats
/// @author Danil Sakhinov
/// @dev Allows to exchange between fiats and crypto coins
/// @dev Exchanges using USDC liquidity pool
/// @dev Uses Narfex oracle to get prices
/// @dev Supports tokens with a transfer fee
contract NarfexExchangerRouter3 is Ownable, ReentrancyGuard {
    using Address for address;

    /// Structures for solving the problem of limiting the number of variables

    struct ExchangeData {
        uint rate;
        uint inAmount;
        uint outAmount;
    }

    struct SwapData {
        address[] path;
        uint[] amounts;
        bool isExactOut;
        uint amount;
        uint inAmount;
        uint inAmountMax;
        uint outAmount;
        uint outAmountMin;
        uint deadline;
        address payable from; /// Sender address
        address payable to; /// Receiver address
    }

    struct Token {
        address addr;
        bool isFiat;
        int commission;
        uint price;
        uint reward;
        uint transferFee;
    }

    IERC20 public USDC;
    IWETH public WETH;
    INarfexOracle internal oracle;
    INarfexExchangerPool internal pool;

    uint constant PRECISION = 10**18;
    uint internal USDC_PRECISION = 10**6;
    uint constant PERCENT_PRECISION = 10**4;
    uint constant MAX_INT = 2**256 - 1;

    /// @param _oracleAddress NarfexOracle address
    /// @param _poolAddress NarfexExchangerPool address
    /// @param _usdcAddress USDC address
    /// @param _wethAddress WrapETH address
    constructor (
        address _oracleAddress,
        address _poolAddress,
        address _usdcAddress,
        address _wethAddress
    ) {
        oracle = INarfexOracle(_oracleAddress);
        USDC = IERC20(_usdcAddress);
        WETH = IWETH(_wethAddress);
        pool = INarfexExchangerPool(_poolAddress);
        if (block.chainid == 56 || block.chainid == 97) {
            USDC_PRECISION = 10**18;
        }
    }

    /// @notice Checking for an outdated transaction
    /// @param deadline Limit block timestamp
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "Transaction expired");
        _;
    }

    event SwapFiat(address indexed _account, address _fromToken, address _toToken, ExchangeData _exchange);
    event SwapDEX(address indexed _account, address _fromToken, address _toToken, uint inAmount, uint outAmount);

    /// @notice Default function for ETH receive. Accepts ETH only from WETH contract
    receive() external payable {
        assert(msg.sender == address(WETH));
    }

    /// @notice Assigns token data from oracle to structure with token address
    /// @param addr Token address
    /// @param t Token data from the oracle
    /// @return New structure with addr
    function _assignTokenData(address addr, INarfexOracle.TokenData memory t)
        internal pure returns (Token memory)
    {
        return Token(addr, t.isFiat, t.commission, t.price, t.reward, t.transferFee);
    }

    /// @notice Returns the price of the token quantity in USDC equivalent
    /// @param _token Token address
    /// @param _amount Token amount
    /// @return USDC amount
    function _getUSDCValue(address _token, int _amount) internal view returns (int) {
        if (_amount == 0) return 0;
        uint uintValue = oracle.getPrice(_token) * uint(_amount) / USDC_PRECISION;
        return _amount >= 0
            ? int(uintValue)
            : -int(uintValue);
    }

    /// @notice Calculates prices and commissions when exchanging with fiat
    /// @param A First token
    /// @param B Second token
    /// @param _amount The amount of one of the tokens. Depends on _isExactOut
    /// @param _isExactOut Is the specified amount an output value
    /// @dev The last parameter shows the direction of the exchange
    function _getExchangeValues(Token memory A, Token memory B, uint _amount, bool _isExactOut)
        internal view returns (ExchangeData memory exchange)
    {
        /// Calculate price
        {
            uint priceA = A.addr == address(USDC) ? USDC_PRECISION : A.price;
            uint priceB = B.addr == address(USDC) ? USDC_PRECISION : B.price;
            exchange.rate = priceA * USDC_PRECISION / priceB;
        }

        /// Calculate clear amounts
        exchange.inAmount = _isExactOut
            ? _amount * USDC_PRECISION / exchange.rate
            : _amount;
        exchange.outAmount = _isExactOut
            ? _amount
            : _amount * exchange.rate / USDC_PRECISION;
    }

    /// @notice Only exchanges between fiats
    /// @param _fromAddress Recipient address
    /// @param _toAddress Receiver address
    /// @param A First token
    /// @param B Second token
    /// @param exchange Calculated values to exchange
    function _swapFiats(
        address _fromAddress,
        address _toAddress,
        Token memory A,
        Token memory B,
        ExchangeData memory exchange
    ) private {
        require(INarfexFiat(A.addr).balanceOf(_fromAddress) >= exchange.inAmount, "Not enough balance");

        /// Exchange tokens
        INarfexFiat(A.addr).burnFrom(_fromAddress, exchange.inAmount);
        INarfexFiat(B.addr).mintTo(_toAddress, exchange.outAmount);

        emit SwapFiat(_toAddress, A.addr, B.addr, exchange);
    }

    /// @notice Fiat and USDC Pair Exchange
    /// @param data Swap data
    /// @param A First token
    /// @param B Second token
    /// @param exchange Calculated values to exchange
    /// @param _isItSwapWithDEX Cancels sending USDC to the user
    /// @dev The last parameter is needed for further or upcoming work with DEX
    function _swapFiatAndUSDC(
        SwapData memory data,
        Token memory A,
        Token memory B,
        ExchangeData memory exchange,
        bool _isItSwapWithDEX
    ) private returns (uint usdcAmount) {
        if (A.addr == address(USDC)) {
            /// If conversion from USDC to fiat
            if (!_isItSwapWithDEX) { 
                /// Transfer from the account
                USDC.transferFrom(data.from, address(pool), exchange.inAmount);
            } /// ELSE: USDC must be already transferred to the pool by DEX
            /// Mint fiat to the final account
            INarfexFiat(B.addr).mintTo(data.to, exchange.outAmount);
        } else {
            /// If conversion from fiat to usdc
            require(pool.getBalance() >= exchange.outAmount, "Not enough liquidity pool amount");
            /// Burn fiat from account
            INarfexFiat(A.addr).burnFrom(data.from, exchange.inAmount);
            /// Then transfer USDC
            if (!_isItSwapWithDEX) {
                /// Transfer USDC to the final account
                USDC.transferFrom(address(pool), data.to, exchange.outAmount);
            }
            usdcAmount = exchange.outAmount;
        }

        emit SwapFiat(data.to, A.addr, B.addr, exchange);
    }

    /// @notice Truncates the path, excluding the fiat from it
    /// @param _path An array of addresses representing the exchange path
    /// @param isFromFiat Indicates the direction of the route (Fiat>DEX of DEX>Fiat)
    function _getDEXSubPath(address[] memory _path, bool isFromFiat) internal pure returns (address[] memory) {
        address[] memory path = new address[](_path.length - 1);
        for (uint i = 0; i < path.length; i++) {
            path[i] = _path[isFromFiat ? i + 1 : i];
        }
        return path;
    }

    /// @notice Gets the reserves of tokens in the path and calculates the final value
    /// @param data Prepared swap data
    /// @dev Updates the data in the structure passed as a parameter
    function _processSwapData(SwapData memory data) internal view {
        if (data.isExactOut) {
            data.amounts = PancakeLibrary.getAmountsIn(data.outAmount, data.path);
            data.inAmount = data.amounts[0];
        } else {
            data.amounts = PancakeLibrary.getAmountsOut(data.inAmount, data.path);
            data.outAmount = data.amounts[data.amounts.length - 1];
        }
    }

    /// @notice Exchange only between crypto Сoins through liquidity pairs
    /// @param data Prepared swap data
    /// @param A Input token data
    /// @param B Output token data
    function _swapOnlyDEX(
        SwapData memory data,
        Token memory A,
        Token memory B
        ) private
    {
        uint transferInAmount;
        if (data.isExactOut) {
            /// Increase output amount by outgoing token fee for calculations
            data.outAmount = B.transferFee > 0
                ? data.amount * (PERCENT_PRECISION + B.transferFee) / PERCENT_PRECISION
                : data.amount;
        } else {
            transferInAmount = data.amount;
            /// Decrease input amount for calculations
            data.inAmount = A.transferFee > 0
                ? data.amount * (PERCENT_PRECISION - A.transferFee) / PERCENT_PRECISION
                : data.amount;
        }
        /// Calculate the opposite value
        _processSwapData(data);

        if (data.isExactOut) {
            /// Increase input amount by inbound token fee
            transferInAmount = A.transferFee > 0
                ? data.inAmount * (PERCENT_PRECISION + A.transferFee) / PERCENT_PRECISION
                : data.inAmount;
            require(data.inAmount <= data.inAmountMax, "Input amount is higher than maximum");
        } else {
            require(data.outAmount >= data.outAmountMin, "Output amount is lower than minimum");
        }
        address firstPair = PancakeLibrary.pairFor(data.path[0], data.path[1]);
        if (A.addr == address(WETH)) {
            /// BNB insert
            require(msg.value >= transferInAmount, "BNB is not sended");
            WETH.deposit{value: transferInAmount}();
            assert(WETH.transfer(firstPair, transferInAmount));
            if (msg.value > transferInAmount) {
                /// Return unused BNB
                data.from.transfer(msg.value - transferInAmount);
            }
        } else {
            /// Coin insert
            SafeERC20.safeTransferFrom(IERC20(data.path[0]), data.from, firstPair, transferInAmount);
        }
        if (B.addr == address(WETH)) {
            /// Send BNB after swap
            _swapDEX(data.amounts, data.path, address(this));
            WETH.withdraw(data.outAmount);
            data.to.transfer(data.outAmount);
        } else {
            /// Send Coin after swap
            _swapDEX(data.amounts, data.path, data.to);
        }
        emit SwapDEX(data.to, A.addr, B.addr, data.inAmount, data.outAmount);
    }

    /// @notice Exchange through liquidity pairs along the route
    /// @param amounts Pre-read reserves in liquidity pairs
    /// @param path An array of addresses representing the exchange path
    /// @param _to Address of the recipient
    function _swapDEX(uint[] memory amounts, address[] memory path, address _to) private {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PancakeLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2
                ? PancakeLibrary.pairFor(output, path[i + 2])
                : _to;
            IPancakePair(PancakeLibrary.pairFor(input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    /// @notice Fiat to crypto Coin exchange and vice versa
    /// @param data Prepared swap data
    /// @param F Fiat token data
    /// @param C Coin token data
    /// @param isFromFiat Exchange direction
    /// @dev Takes into account tokens with transfer fees
    function _swapFiatWithDEX(
        SwapData memory data,
        Token memory F, // Fiat
        Token memory C, // Coin
        bool isFromFiat
        ) private
    {
        /// USDC token data
        Token memory U = _assignTokenData(address(USDC), oracle.getTokenData(address(USDC), false));
        uint lastIndex = data.path.length - 1;

        require((isFromFiat && data.path[0] == U.addr)
            || (!isFromFiat && data.path[lastIndex] == U.addr),
            "The exchange between fiat and crypto must be done via USDC");

        ExchangeData memory exchange;

        if (data.isExactOut) {
            /// If exact OUT
            if (isFromFiat) { /// FIAT > USDC > DEX > COIN!!
                /// Calculate other amounts from the start amount data
                data.outAmount = data.amount;
                if (C.transferFee > 0) {
                    /// Increasing the output amount offsets the loss from the fee
                    data.outAmount = data.outAmount * (PERCENT_PRECISION + C.transferFee) / PERCENT_PRECISION;
                }
                _processSwapData(data);
                exchange = _getExchangeValues(F, U, data.inAmount, true);
                require(exchange.inAmount <= data.inAmountMax, "Input amount is higher than maximum");
                /// Swap Fiat with USDC
                _swapFiatAndUSDC(data, F, U, exchange, true);
                /// Transfer USDC from the Pool to the first pair
                {
                    address firstPair = PancakeLibrary.pairFor(U.addr, data.path[1]);
                    SafeERC20.safeTransferFrom(USDC, address(pool), firstPair, data.inAmount);
                }
                /// Swap and send to the account
                if (C.addr == address(WETH)) {
                    /// Swap with BNB out
                    _swapDEX(data.amounts, data.path, address(this));
                    WETH.withdraw(data.outAmount);
                    data.to.transfer(data.outAmount);
                } else {
                    /// Swap with coin out
                    _swapDEX(data.amounts, data.path, data.to);
                }
                emit SwapDEX(data.to, data.path[0], data.path[lastIndex], data.inAmount, data.outAmount);
            } else { /// COIN > DEX > USDC > FIAT!!
                /// Calculate other amounts from the start amount data
                exchange = _getExchangeValues(U, F, data.amount, true);
                data.outAmount = exchange.inAmount;
                _processSwapData(data);
                require(data.inAmount <= data.inAmountMax, "Input amount is higher than maximum");
                /// Transfer Coin from the account to the first pair
                {
                    address firstPair = PancakeLibrary.pairFor(C.addr, data.path[1]);
                    if (C.addr == address(WETH)) {
                        /// BNB transfer
                        require(msg.value >= data.inAmount, "BNB is not sended");
                        WETH.deposit{value: data.inAmount}();
                        assert(WETH.transfer(firstPair, data.inAmount));
                        if (msg.value > data.inAmount) {
                            /// Return unused BNB
                            data.from.transfer(msg.value - data.inAmount);
                        }
                    } else {
                        /// Send increased coin amount from the account to DEX
                        uint inAmountWithFee = C.transferFee > 0
                        ? data.inAmount * (PERCENT_PRECISION + C.transferFee) / PERCENT_PRECISION
                        : data.inAmount;
                        SafeERC20.safeTransferFrom(IERC20(C.addr), data.from, firstPair, inAmountWithFee);
                    }
                }
                /// Swap and send USDC to the pool
                _swapDEX(data.amounts, data.path, address(pool));
                emit SwapDEX(data.to, data.path[0], data.path[lastIndex], data.inAmount, data.outAmount);
                /// Swap USDC and Fiat
                _swapFiatAndUSDC(data, U, F, exchange, true);
            }
        } else {
            /// If exact IN
            if (isFromFiat) { /// FIAT!! > USDC > DEX > COIN
                /// Calculate other amounts from the start amount data
                exchange = _getExchangeValues(F, U, data.amount, false);
                data.inAmount = exchange.outAmount;
                _processSwapData(data);
                require(data.outAmount >= data.outAmountMin, "Output amount is lower than minimum");
                /// Swap Fiat with USDC
                _swapFiatAndUSDC(data, F, U, exchange, true);
                /// Transfer USDC from the Pool to the first pair
                {
                    address firstPair = PancakeLibrary.pairFor(U.addr, data.path[1]);
                    SafeERC20.safeTransferFrom(USDC, address(pool), firstPair, data.inAmount);
                    /// TransferFee only affects delivered amount
                }
                /// Swap and send to the account
                if (C.addr == address(WETH)) {
                    /// Swap with ETH transfer
                    _swapDEX(data.amounts, data.path, address(this));
                    WETH.withdraw(data.outAmount);
                    data.to.transfer(data.outAmount);
                } else {
                    /// Swap with coin transfer
                    _swapDEX(data.amounts, data.path, data.to);
                }
                emit SwapDEX(data.to, data.path[0], data.path[lastIndex], data.inAmount, data.outAmount);
            } else { /// COIN!! > DEX > USDC > FIAT
                /// Calculate other amounts from the start amount data
                data.inAmount = data.amount;
                if (C.transferFee > 0) {
                    /// DEX swap with get a reduced value
                    data.inAmount = data.inAmount * (PERCENT_PRECISION - C.transferFee) / PERCENT_PRECISION;
                }
                _processSwapData(data);
                exchange = _getExchangeValues(U, F, data.outAmount, false);
                require(exchange.outAmount >= data.outAmountMin, "Output amount is lower than minimum");
                /// Transfer Coin from the account to the first pair
                {
                    address firstPair = PancakeLibrary.pairFor(C.addr, data.path[1]);
                    if (C.addr == address(WETH)) {
                        /// BNB transfer
                        require(msg.value >= data.amount, "BNB is not sended");
                        WETH.deposit{value: data.amount}();
                        assert(WETH.transfer(firstPair, data.amount));
                    } else {
                        /// Coin transfer
                        SafeERC20.safeTransferFrom(IERC20(C.addr), data.from, firstPair, data.amount); /// Full amount
                    }
                }
                /// Swap and send USDC to the pool
                _swapDEX(data.amounts, data.path, address(pool));
                emit SwapDEX(data.to, data.path[0], data.path[lastIndex], data.inAmount, data.outAmount);
                /// Swap USDC and Fiat
                _swapFiatAndUSDC(data, U, F, exchange, true);
            }
        }
    }

    /// @notice Main Routing Exchange Function
    /// @param data Prepared data for exchange
    function _swap(
        SwapData memory data
        ) internal nonReentrant
    {
        require(data.path.length > 1, "Path length must be at least 2 addresses");
        uint lastIndex = data.path.length - 1;

        Token memory A; /// First token
        Token memory B; /// Last token
        {
            /// Get the oracle data for the first and last tokens
            address[] memory sideTokens = new address[](2);
            sideTokens[0] = data.path[0];
            sideTokens[1] = data.path[lastIndex];
            INarfexOracle.TokenData[] memory tokensData = oracle.getTokensData(sideTokens, true);
            A = _assignTokenData(sideTokens[0], tokensData[0]);
            B = _assignTokenData(sideTokens[1], tokensData[1]);
        }
        require(A.addr != B.addr, "Can't swap the same tokens");

        if (A.isFiat && B.isFiat)
        { /// If swap between fiats
            ExchangeData memory exchange = _getExchangeValues(A, B, data.amount, data.isExactOut);
            _swapFiats(data.from, data.to, A, B, exchange);
            return;
        }
        if (!A.isFiat && !B.isFiat)
        { /// Swap on DEX only
            _swapOnlyDEX(data, A, B);
            return;
        }
        if ((A.isFiat && B.addr == address(USDC))
            || (B.isFiat && A.addr == address(USDC)))
        { /// If swap between fiat and USDC in the pool
            ExchangeData memory exchange = _getExchangeValues(A, B, data.amount, data.isExactOut);
            _swapFiatAndUSDC(data, A, B, exchange, false);
            return;
        }

        /// Swap with DEX and Fiats
        data.path = _getDEXSubPath(data.path, A.isFiat);
        _swapFiatWithDEX(data, A.isFiat ? A : B, A.isFiat ? B : A, A.isFiat);  
    }

    /// @notice Set a new pool address
    /// @param _newPoolAddress Another pool address
    /// @param _decimals Pool token decimals
    function setPool(address _newPoolAddress, uint8 _decimals) public onlyOwner {
        pool = INarfexExchangerPool(_newPoolAddress);
        USDC_PRECISION = 10**_decimals;
    }

    /// @notice Set a new oracle address
    /// @param _newOracleAddress Another oracle address
    function setOracle(address _newOracleAddress) public onlyOwner {
        oracle = INarfexOracle(_newOracleAddress);
    }

    /// @notice Swap tokens public function
    /// @param path An array of addresses representing the exchange path
    /// @param isExactOut Is the amount an output value
    /// @param amountLimit Becomes the min output amount for isExactOut=true, and max input for false
    /// @param deadline The transaction must be completed no later than the specified time
    /// @dev If the user wants to get an exact amount in the output, isExactOut should be true
    /// @dev Fiat to crypto must be exchanged via USDC
    function swap(
        address[] memory path,
        bool isExactOut,
        uint amount,
        uint amountLimit,
        uint deadline) public payable ensure(deadline)
    {
        SwapData memory data;
        data.from = payable(msg.sender);
        data.to = payable(msg.sender);
        data.path = path;
        data.isExactOut = isExactOut;
        data.amount = amount;
        data.inAmount = isExactOut ? 0 : amount;
        data.inAmountMax = isExactOut ? amountLimit : MAX_INT;
        data.outAmount = isExactOut ? amount : 0;
        data.outAmountMin = isExactOut ? 0 : amountLimit;

        _swap(data);
    }

    function getPool() public view returns(address) {
        return address(pool);
    }

    function getOracle() public view returns(address) {
        return address(oracle);
    }
}