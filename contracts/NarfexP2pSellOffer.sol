//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./INarfexP2pFactory.sol";
import "./INarfexP2pRouter.sol";

/// @title Sell offer in Narfex P2P service
/// @author Danil Sakhinov
/// @dev Allow to create trades with current offer parameters
contract NarfexP2pSellOffer {

    struct Trade {
        uint8 status; // 0 = closed, 1 = active
        uint32 createDate;
        uint moneyAmount; // Fiat to send to bank account
        uint fiatAmount; // Initial amount - commission - fee
        address client;
        address lawyer;
        string bankAccount;
        bytes32 clientPublicKey;
        bytes32 chatRoom;
    }

    INarfexP2pFactory immutable factory;
    address immutable public fiat;
    address immutable public owner;
    uint constant DAY = 86400;
    uint constant PERCENT_PRECISION = 10**4;
    uint constant ETH_PRECISION = 10**18;

    bytes32 public ownerPublicKey;
    uint16 public commission;
    uint public minTradeAmount;
    uint public maxTradeAmount;
    uint public offerLimit;
    bool public isKYCRequired;

    address[] private _currentClients;
    bool private _isActive;
    bool[24][7] private _activeHours;
    mapping(address => Trade) private _trades;
    mapping(address => bool) private _blacklist;

    event Blacklisted(address _client);
    event Unblacklisted(address _client);
    event Disable();
    event Enable();
    event ScheduleUpdate();
    event AddBankAccount(uint _index, string _jsonData);
    event ClearBankAccount(uint _index);
    event KYCRequired();
    event KYCUnrequired();
    event SetCommission(uint _percents);
    event SetLimit(uint _offerLimit);
    event CreateTrade(address _client, uint moneyAmount, uint fiatAmount);
    event Withdraw(uint _amount);
    event SetLawyer(address _client, address _offer, address _lawyer);

    /// @param _factory Factory address
    /// @param _owner Validator as offer owner
    /// @param _fiatAddress Fiat
    /// @param _ownerPublicKey Public key for encrypting banking data
    /// @param _commission in percents with precision 4 digits (10000 = 100%);
    constructor(
        address _factory,
        address _owner,
        address _fiatAddress,
        bytes32 _ownerPublicKey,
        uint16 _commission
    ) {
        owner = _owner;
        ownerPublicKey = _ownerPublicKey;
        fiat = _fiatAddress;
        factory = INarfexP2pFactory(_factory);
        _isActive = true;
        /// Fill all hours as active
        unchecked {
            for (uint8 w; w < 7; w++) {
                for (uint8 h; h < 24; h++) {
                    _activeHours[w][h] = true;
                }
            }
        }
        isKYCRequired = true;
        setCommission(_commission);
        emit KYCRequired();
        emit SetCommission(_commission);
        emit Enable();
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Caller is not the owner");
        _;
    }

    /// @notice Check trade is active
    /// @return isActive
    /// @dev Checks permanent activity, allowance by Protocol and schedule
    function getIsActive() public view returns(bool isActive) {
        if (!_isActive) return false;
        if (factory.getCanTrade(owner)) return false;
        uint8 weekDay = uint8((block.timestamp / DAY + 4) % 7);
        uint8 hour = uint8((block.timestamp / 60 / 60) % 24);
        return _activeHours[weekDay][hour];
    }

    /// @notice Set current offer limit
    /// @param _offerLimit Fiat amount
    function setLimit(uint _offerLimit) public onlyOwner {
        offerLimit = _offerLimit;
        emit SetLimit(_offerLimit);
    }

    /// @notice Get fiat limit for a new trade
    /// @return Fiat limit
    function getTradeLimitAvailable() private view returns(uint) {
        uint limit = maxTradeAmount;
        if (offerLimit < limit) limit = offerLimit;
        return limit;
    }

    /// @notice Get sum of Protocol and Offer commissions
    /// @return Commission in percents with precision 4 digits
    function getTotalCommission() private view returns(uint) {
        return uint(factory.getFiatFee(fiat) + commission);
    }

    /// @notice Sets offer commission
    /// @param _percents Commission in percents with 4 digits of precision
    function setCommission(uint16 _percents) public onlyOwner {
        require (factory.getFiatFee(fiat) + _percents < PERCENT_PRECISION, "Commission too high");
        commission = _percents;
        emit SetCommission(_percents);
    }

    /// @notice Get offer data in one request
    /// @return Offer address
    /// @return Fiat address
    /// @return Validator address
    /// @return Is this Buy offer
    /// @return Is current offer active now
    /// @return Offer commission
    /// @return Total commission
    /// @return Minimum fiat amount for trade start
    /// @return Maximum fiat amount fot trade start
    /// @return Trades quote
    function getOffer() public view returns(address, address, address, bool, bool, uint, uint, uint, uint, uint) {
        return (
            address(this),
            fiat,
            owner,
            false,
            getIsActive(),
            uint(commission),
            getTotalCommission(),
            minTradeAmount,
            getTradeLimitAvailable(),
            getTradesQuote()
        );
    }

    /// @notice Get current client trade
    /// @param _client Client account address
    /// @return Trade data
    function getTrade(address _client) public view returns(Trade memory) {
        Trade memory trade = _trades[_client];
        return trade;
    }

    /// @notice Get current trades
    /// @return Array of Trade structure
    function getCurrentTrades() public view returns(Trade[] memory) {
        Trade[] memory trades = new Trade[](_currentClients.length);
        unchecked {
            for (uint i; i < _currentClients.length; i++) {
                trades[i] = getTrade(_currentClients[i]);
            }
        }
        return trades;
    }

    /// @notice Returns the offer schedule
    /// @return Activity hours
    function getSchedule() public view returns(bool[24][7] memory) {
        return _activeHours;
    }

    /// @notice Set new schedule
    /// @param _schedule [weekDay][hour] => isActive
    function setSchedule(bool[24][7] calldata _schedule) public onlyOwner {
        _activeHours = _schedule;
        emit ScheduleUpdate();
    }

    /// @notice Get is client blacklisted by Offer or Protocol
    /// @param _client Account address
    /// @return Is blacklisted
    function getIsBlacklisted(address _client) public view returns(bool) {
        return _blacklist[_client] || factory.getIsBlacklisted(_client);
    }

    /// @notice Add client to offer blacklist
    /// @param _client Account address
    function addToBlacklist(address _client) public onlyOwner {
        require(!_blacklist[_client], "Client already in blacklist");
        _blacklist[_client] = true;
        emit Blacklisted(_client);
    }

    /// @notice Remove client from offer blacklist
    /// @param _client Account address
    function removeFromBlacklist(address _client) public onlyOwner {
        require(_blacklist[_client], "Client is not in your blacklist");
        _blacklist[_client] = false;
        emit Unblacklisted(_client);
    }

    /// @notice Set the offer is permanently active
    /// @param _newState Is active bool value
    function setActiveness(bool _newState) public onlyOwner {
        require(_isActive != _newState, "Already seted");
        _isActive = _newState;
        if (_newState) {
            emit Enable();
        } else {
            emit Disable();
        }
    }

    /// @notice Set is KYC verification required
    /// @param _newState Is required
    function setKYCRequirement(bool _newState) public onlyOwner {
        require(isKYCRequired != _newState, "Already seted");
        isKYCRequired = _newState;
        if (_newState) {
            emit KYCRequired();
        } else {
            emit KYCUnrequired();
        }
    }

    /// @notice Is account have a trade in this offer
    /// @param _client Account address
    /// @return Is have trade
    function isClientHaveTrade(address _client) public view returns(bool) {
        unchecked {
            for (uint i; i < _currentClients.length; i++) {
                if (_currentClients[i] == _client) return true;
            }
        }
        return false;
    }

    /// @notice Returns how many trades can be created
    /// @return Trades amount
    function getTradesQuote() public view returns(uint) {
        uint limit = factory.getTradesLimit();
        return limit > _currentClients.length
            ? limit - _currentClients.length
            : 0;
    }

    /// @notice Add random lawyer to the trade
    /// @param _client Client in a trade
    /// @dev Can be called by client and validator once per trade
    /// @dev Factory can change the lawyer at any time
    function setLawyer(address _client) public {
        Trade storage trade = _trades[_client];
        require(trade.status > 0, "Trade is not active");
        require(trade.lawyer == address(0) || msg.sender == address(factory), "Trade already have a lawyer");
        require(
            msg.sender == address(this)
            || msg.sender == owner
            || msg.sender == trade.client
            || msg.sender == address(factory),
            "You don't have permission to this trade"
            );
        trade.lawyer = factory.getLawyer();
        emit SetLawyer(_client, address(this), trade.lawyer);
    }

    /// @notice Creade a new trade
    /// @param fiatAmount How much client's fiat will be locked in the offer contract
    /// @param bankAccount Encrypted bank account data
    /// @param clientPublicKey Client's public key for decryption
    function createTrade(
        uint fiatAmount,
        string calldata bankAccount,
        bytes32 clientPublicKey
    ) public {
        require(getIsActive(), "Offer is not active now");
        require(!getIsBlacklisted(msg.sender), "Your account is blacklisted");
        require(!isKYCRequired || factory.isKYCVerified(msg.sender), "KYC verification required");
        require(!isClientHaveTrade(msg.sender), "You already have a trade");
        require(getTradesQuote() >= 1, "Too much trades in this offer");

        uint moneyAmount = fiatAmount - (fiatAmount * getTotalCommission() / PERCENT_PRECISION);
        require(moneyAmount >= minTradeAmount, "Too small trade");
        require(fiatAmount <= getTradeLimitAvailable(), "Too big trade");

        /// Transfer client's funds
        SafeERC20.safeTransferFrom(IERC20(fiat), msg.sender, address(this), fiatAmount);
        offerLimit -= fiatAmount;

        bytes32 chatRoom = keccak256(abi.encodePacked(
            block.timestamp,
            owner,
            msg.sender
            ));
        _trades[msg.sender] = Trade({
            status: 1,
            createDate: uint32(block.timestamp),
            moneyAmount: moneyAmount,
            fiatAmount: fiatAmount,
            client: msg.sender,
            lawyer: address(0),
            clientPublicKey: clientPublicKey,
            bankAccount: bankAccount,
            chatRoom: chatRoom
        });
        _currentClients.push(msg.sender);

        emit CreateTrade(msg.sender, moneyAmount, fiatAmount);
    }

    function removeClientFromCurrent(address _client) private {
        unchecked {
            uint j;
            for (uint i; i < _currentClients.length - 1; i++) {
                if (_currentClients[i] == _client) {
                    j++;
                }
                if (j > 0) {
                    _currentClients[i] = _currentClients[i + 1];
                }
            }
            if (j > 0) {
                _currentClients.pop();
            }
        }
    }

    /// @notice Cancel trade
    /// @param _client Client account address
    /// @dev If the deal is canceled by a lawyer, he will be compensated for gas costs
    /// @dev Can't be called by client
    function cancelTrade(address _client) public {
        uint gas = gasleft() * tx.gasprice;
        Trade storage trade = _trades[_client];
        require (trade.status > 0, "Trade is not active");
        require (msg.sender == owner || msg.sender == trade.lawyer, "You don't have permission");

        uint fiatAmount = trade.fiatAmount;
        if (msg.sender == trade.lawyer) {
            /// If cancel called by lawyer send fiat equivalent of gas to lawyer
            uint ethFiatPrice = ETH_PRECISION / factory.getETHPrice(fiat);
            uint gasFiatDeduction = ethFiatPrice * gas;
            if (gasFiatDeduction > fiatAmount) {
                gasFiatDeduction = fiatAmount;
            }
            fiatAmount -= gasFiatDeduction;
            SafeERC20.safeTransferFrom(IERC20(fiat), address(this), trade.lawyer, gasFiatDeduction);
        }
        /// Send back to client
        SafeERC20.safeTransferFrom(IERC20(fiat), address(this), trade.client, fiatAmount);
        offerLimit += trade.fiatAmount;

        trade.status = 0;
        removeClientFromCurrent(_client);
    }

    /// @notice Finish the trade
    /// @param _client Client account address
    /// @dev If the trade is finished by a lawyer, he will be compensated for gas costs
    /// @dev Can be called by client of lawyer
    function confirmTrade(address _client) public {
        uint gas = gasleft() * tx.gasprice;
        Trade storage trade = _trades[_client];
        require (trade.status > 0, "Trade is not active");
        require (msg.sender == trade.client || msg.sender == trade.lawyer, "You don't have permission");
        
        uint fiatAmount = trade.fiatAmount;
        /// Pay fee to the pool
        uint fee = fiatAmount * factory.getFiatFee(fiat) / PERCENT_PRECISION;
        INarfexP2pRouter router = INarfexP2pRouter(factory.getRouter());
        router.payFee(fiat, fee);
        fiatAmount -= fee;

        if (msg.sender == trade.lawyer) {
            /// Subtract fiat equivalent of gas deduction
            uint ethFiatPrice = ETH_PRECISION / factory.getETHPrice(fiat);
            uint gasFiatDeduction = ethFiatPrice * gas;
            SafeERC20.safeTransferFrom(IERC20(fiat), address(this), trade.lawyer, gasFiatDeduction);
            fiatAmount -= gasFiatDeduction;
        }

        SafeERC20.safeTransferFrom(IERC20(fiat), address(this), owner, fiatAmount);

        trade.status = 0;
        removeClientFromCurrent(_client);
    }
}