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
    bytes21 private _activeHours; // Active hours of week. 21 bytes = 24 x 7 / 8
    mapping(address => Trade) private _trades;
    mapping(address => bool) private _blacklist;

    event P2pOfferBlacklisted(address indexed _client);
    event P2pOfferUnblacklisted(address indexed _client);
    event P2pOfferDisable();
    event P2pOfferEnable();
    event P2pOfferScheduleUpdate(bytes21 _schedule);
    event P2pOfferKYCRequired();
    event P2pOfferKYCUnrequired();
    event P2pOfferSetCommission(uint _percents);
    event P2pOfferSetLimit(uint _offerLimit);
    event P2pCreateTrade(address indexed _client, uint moneyAmount, uint fiatAmount);
    event P2pSetLawyer(address indexed _client, address _offer, address indexed _lawyer);
    event P2pConfirmTrade(address indexed _client, address indexed _lawyer);
    event P2pCancelTrade(address indexed _client, address indexed _lawyer);
    event P2pSetTradeAmounts(uint _minTradeAmount, uint _maxTradeAmount);

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
        uint16 _commission,
        uint _minTradeAmount,
        uint _maxTradeAmount
    ) {
        fiat = _fiatAddress;
        factory = INarfexP2pFactory(_factory);
        require (factory.getFiatFee(fiat) + _commission < PERCENT_PRECISION, "Commission too high");
        
        owner = _owner;
        ownerPublicKey = _ownerPublicKey;
        _isActive = true;
        /// Fill all hours as active
        _activeHours = ~bytes21(0);
        isKYCRequired = true;
        commission = _commission;
        minTradeAmount = _minTradeAmount;
        maxTradeAmount = _maxTradeAmount;
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
        if (!factory.getCanTrade(owner)) return false;
        uint8 weekDay = uint8((block.timestamp / DAY + 4) % 7);
        uint8 hour = uint8((block.timestamp / 60 / 60) % 24);
        uint bitIndex = 7 * weekDay + hour;
        bytes21 hourBit = ~(~bytes21(0) >> 1 << 1) << bitIndex;
        return _activeHours & hourBit > 0;
    }

    /// @notice Set current offer limit
    /// @param _offerLimit Fiat amount
    function setLimit(uint _offerLimit) public onlyOwner {
        offerLimit = _offerLimit;
        emit P2pOfferSetLimit(_offerLimit);
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
        emit P2pOfferSetCommission(_percents);
    }

    /// @notice Sets trade minumum and maximum amounts
    /// @param _minTradeAmount Minimal trade amount
    /// @param _maxTradeAmount Maximal trade amount
    function setTradeAmounts(uint _minTradeAmount, uint _maxTradeAmount) public onlyOwner {
        minTradeAmount = _minTradeAmount;
        maxTradeAmount = _maxTradeAmount;
        emit P2pSetTradeAmounts(_minTradeAmount, _maxTradeAmount);
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
    function getSchedule() public view returns(bytes21) {
        return _activeHours;
    }

    /// @notice Set new schedule
    /// @param _schedule Schedule bytes
    function setSchedule(bytes21 _schedule) public onlyOwner {
        _activeHours = _schedule;
        emit P2pOfferScheduleUpdate(_schedule);
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
        emit P2pOfferBlacklisted(_client);
    }

    /// @notice Remove client from offer blacklist
    /// @param _client Account address
    function removeFromBlacklist(address _client) public onlyOwner {
        require(_blacklist[_client], "Client is not in your blacklist");
        _blacklist[_client] = false;
        emit P2pOfferUnblacklisted(_client);
    }

    /// @notice Set the offer is permanently active
    /// @param _newState Is active bool value
    function setActiveness(bool _newState) public onlyOwner {
        require(_isActive != _newState, "Already seted");
        _isActive = _newState;
        if (_newState) {
            emit P2pOfferEnable();
        } else {
            emit P2pOfferDisable();
        }
    }

    /// @notice Set is KYC verification required
    /// @param _newState Is required
    function setKYCRequirement(bool _newState) public onlyOwner {
        require(isKYCRequired != _newState, "Already seted");
        isKYCRequired = _newState;
        if (_newState) {
            emit P2pOfferKYCRequired();
        } else {
            emit P2pOfferKYCUnrequired();
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
        emit P2pSetLawyer(_client, address(this), trade.lawyer);
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

        emit P2pCreateTrade(msg.sender, moneyAmount, fiatAmount);
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
            emit P2pCancelTrade(_client, trade.lawyer);
        } else {
            emit P2pCancelTrade(_client, address(0));
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
            emit P2pConfirmTrade(_client, trade.lawyer);
        } else {
            emit P2pConfirmTrade(_client, address(0));
        }

        SafeERC20.safeTransferFrom(IERC20(fiat), address(this), owner, fiatAmount);

        trade.status = 0;
        removeClientFromCurrent(_client);
    }

    /// @notice Update all settings
    /// @param _commission New commission
    /// @param _minTradeAmount New minimal trade amount
    /// @param _maxTradeAmount New maximum trade amount
    /// @param _schedule New active hours packed to bits
    function setSettings(uint16 _commission, uint _minTradeAmount, uint _maxTradeAmount, bytes21 _schedule) public onlyOwner {
        if (_commission != commission) {
            setCommission(_commission);
        }
        if (_minTradeAmount != minTradeAmount || _maxTradeAmount != maxTradeAmount) {
            setTradeAmounts(_minTradeAmount, _maxTradeAmount);
        }
        if (_schedule != _activeHours) {
            setSchedule(_schedule);
        }
    }
}