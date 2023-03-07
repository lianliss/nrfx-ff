//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import './NarfexExchangerRouter3.sol';

contract NarfexP2pRouter is NarfexExchangerRouter3 {

    uint constant VALIDATOR_POOL_PERCENT = 8000;

    constructor(
        address _oracleAddress,
        address _poolAddress,
        address _usdcAddress,
        address _wbnbAddress
    ) NarfexExchangerRouter3(_oracleAddress, _poolAddress, _usdcAddress, _wbnbAddress) {}

    event Deposit(address indexed _validator, uint _amount);
    event Withdraw(address indexed _validator, uint _amount);

    /// @notice Swap tokens and send to a receiver
    /// @param to Receiver address
    /// @param path An array of addresses representing the exchange path
    /// @param isExactOut Is the amount an output value
    /// @param amountLimit Becomes the min output amount for isExactOut=true, and max input for false
    /// @param deadline The transaction must be completed no later than the specified time
    /// @dev If the user wants to get an exact amount in the output, isExactOut should be true
    /// @dev Fiat to crypto must be exchanged via USDT
    function swapTo(
        address to,
        address[] memory path,
        bool isExactOut,
        uint amount,
        uint amountLimit,
        uint deadline) external payable ensure(deadline)
    {
        SwapData memory data;
        data.from = payable(msg.sender);
        data.to = payable(to);
        data.path = path;
        data.isExactOut = isExactOut;
        data.amount = amount;
        data.inAmount = isExactOut ? 0 : amount;
        data.inAmountMax = isExactOut ? amountLimit : MAX_INT;
        data.outAmount = isExactOut ? amount : 0;
        data.outAmountMin = isExactOut ? 0 : amountLimit;

        _swap(data);
    }

    function swapToETH(address to, address token, uint amount) external {
        SwapData memory data;
        address[] memory path = new address[](3);
        path[0] = token;
        path[1] = address(USDC);
        path[2] = address(WETH);
        data.from = payable(msg.sender);
        data.to = payable(to);
        data.path = path;
        data.isExactOut = false;
        data.amount = amount;
        data.inAmount = amount;
        data.inAmountMax = amount;
        data.outAmount = 0;
        data.outAmountMin = 0;

        _swap(data);
    }

    function deposit(uint _usdcAmount, address _fiatAddress) public nonReentrant returns(uint) {
        /// Get fiat data
        INarfexOracle.TokenData memory fiatData = oracle.getTokenData(_fiatAddress, true);
        require (fiatData.isFiat, "Requested token is not fiat");

        /// Calculate fiat amount
        uint fiatAmount = _usdcAmount * USDC_PRECISION / fiatData.price;
        /// Decrease fiat amount to 80%
        fiatAmount = fiatAmount * VALIDATOR_POOL_PERCENT / PERCENT_PRECISION;

        USDC.transferFrom(msg.sender, address(pool), _usdcAmount);
        INarfexFiat(_fiatAddress).mintTo(msg.sender, fiatAmount);

        /// Increase validator limit
        pool.increaseLimit(msg.sender, _fiatAddress, fiatAmount);
        emit Deposit(msg.sender, _usdcAmount);
        return fiatAmount;
    }

    function withdraw(uint _fiatAmount, address _fiatAddress) public nonReentrant returns(uint) {
        /// Get fiat data
        INarfexOracle.TokenData memory fiatData = oracle.getTokenData(_fiatAddress, true);
        require (fiatData.isFiat, "Requested token is not fiat");

        /// Try to decrease limit and check limit availability
        pool.decreaseLimit(msg.sender, _fiatAddress, _fiatAmount);

        /// Calculate usdc amount
        uint usdcAmount = _fiatAmount * fiatData.price / USDC_PRECISION;
        /// Increase usdc amount to 1/80% (125%)
        usdcAmount = usdcAmount * PERCENT_PRECISION / VALIDATOR_POOL_PERCENT;

        INarfexFiat(_fiatAddress).burnFrom(msg.sender, _fiatAmount);
        USDC.transferFrom(address(pool), msg.sender, usdcAmount);
        emit Withdraw(msg.sender, usdcAmount);
        return usdcAmount;
    }

    function payFee(address _fiatAddress, uint _fiatAmount) public {
        /// Get fiat data
        INarfexOracle.TokenData memory fiatData = oracle.getTokenData(_fiatAddress, true);
        require (fiatData.isFiat, "Requested token is not fiat");

        /// Calculate usdc amount
        uint usdcAmount = _fiatAmount * fiatData.price / USDC_PRECISION;

        INarfexFiat(_fiatAddress).burnFrom(msg.sender, _fiatAmount);
        pool.increaseFeeAmount(usdcAmount);
    }
}