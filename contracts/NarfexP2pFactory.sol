//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./NarfexP2pBuyOffer.sol";
import "./NarfexP2pSellOffer.sol";
import "./INarfexOracle.sol";
import "./INarfexP2pRouter.sol";

interface INarfexKYC {
    function isKYCVerified(address _client) external view returns(bool);
    function getIsBlacklisted(address _account) external view returns(bool);
    function getCanTrade(address _account) external view returns(bool);
}

interface INarfexLawyers {
    function getLawyer() external view returns(address);
}

interface INarfexExchangerPool {
    function getValidatorLimit(address _validator, address _fiatAddress) external view returns(uint);
}

interface IOffer {
    function getOffer() external view returns(address, address, address, bool, bool, uint, uint, uint, uint, uint);
}

/// @title Offers factory for Narfex P2P service
/// @author Danil Sakhinov
/// @dev Allows to create p2p offers
contract NarfexP2pFactory is Ownable {

    struct Offer { /// Offer getter structure
        address offerAddress;
        address fiatAddress;
        address ownerAddress;
        bool isBuy;
        bool isActive;
        uint commission;
        uint totalCommission;
        uint minTrade;
        uint maxTrade;
        uint tradesQuote;
    }

    address immutable public WETH;
    uint constant ETH_PRECISION = 10**18;
    INarfexKYC public kyc;
    INarfexLawyers public lawyers;
    INarfexP2pRouter public router;
    uint public tradesLimit = 2; /// Trades count per one offer in one time

    mapping(address=>address[]) private _buyOffers; /// Fiat=>Offer
    mapping(address=>address[]) private _sellOffers; /// Fiat=>Offer
    mapping(address=>mapping(address=>address)) private _validatorBuyOffers; /// Fiat=>Validator=>Offer
    mapping(address=>mapping(address=>address)) private _validatorSellOffers; /// Fiat=>Validator=>Offer
    mapping(address=>address[]) private _validatorOffers; /// Validator=>Offer
    mapping(address=>uint16) private _fees; /// Protocol fees

    /// @param _WETH Wrap ETH address
    /// @param _kyc KYC contract address
    /// @param _lawyers Lawyers contract address
    /// @param _router NarfexP2pRouter contract address
    constructor(
        address _WETH,
        address _kyc,
        address _lawyers,
        address _router
    ) {
        WETH = _WETH;
        kyc = INarfexKYC(_kyc);
        lawyers = INarfexLawyers(_lawyers);
        router = INarfexP2pRouter(_router);
        emit SetKYCContract(_kyc);
        emit SetLawyersContract(_lawyers);
        emit SetRouter(_router);
        emit SetTradesLimit(2);
    }

    event CreateOffer(address indexed validator, address indexed fiatAddress, address offer, bool isBuy);
    event SetFiatFee(address fiatAddress, uint16 fee);
    event SetRouter(address routerAddress);
    event SetKYCContract(address kycContract);
    event SetLawyersContract(address lawyersContract);
    event SetTradesLimit(uint amount);

    /// @notice Create Buy Offer by validator
    /// @param _fiatAddress Fiat
    /// @param _commission Validator commission with 4 digits of precision (10000 = 100%);
    function createBuyOffer(address _fiatAddress, uint16 _commission) public {
        require(_validatorBuyOffers[_fiatAddress][msg.sender] == address(0), "You already have this offer");
        require(kyc.getCanTrade(msg.sender), "You can't trade");
        require(INarfexOracle(router.getOracle()).getIsFiat(_fiatAddress), "Token is not fiat");
        NarfexP2pBuyOffer offer = new NarfexP2pBuyOffer(address(this), msg.sender, _fiatAddress, _commission);
        _buyOffers[_fiatAddress].push(address(offer));
        _validatorBuyOffers[_fiatAddress][msg.sender] = address(offer);
        _validatorOffers[msg.sender].push(address(offer));
        emit CreateOffer(msg.sender, _fiatAddress, address(offer), true);
    }

    /// @notice Create Buy Offer by validator
    /// @param _fiatAddress Fiat
    /// @param _commission Validator commission with 4 digits of precision (10000 = 100%);
    /// @param _publicKey Validator public key
    function createSellOffer(address _fiatAddress, uint16 _commission, bytes32 _publicKey) public {
        require(_validatorSellOffers[_fiatAddress][msg.sender] == address(0), "You already have this offer");
        require(kyc.getCanTrade(msg.sender), "You can't trade");
        require(INarfexOracle(router.getOracle()).getIsFiat(_fiatAddress), "Token is not fiat");
        NarfexP2pSellOffer offer = new NarfexP2pSellOffer(address(this), msg.sender, _fiatAddress, _publicKey, _commission);
        _sellOffers[_fiatAddress].push(address(offer));
        _validatorSellOffers[_fiatAddress][msg.sender] = address(offer);
        _validatorOffers[msg.sender].push(address(offer));
        emit CreateOffer(msg.sender, _fiatAddress, address(offer), false);
    }

    /// @notice Get all validator offers with data
    /// @param _account Validator
    /// @param _offset Start index
    /// @param _limit Results limit. Zero for no limit
    /// @return array of Offer struct
    function getValidatorOffers(address _account, uint _offset, uint _limit) public view returns(Offer[] memory) {
        return _getOffersData(_validatorOffers[_account], _offset, _limit);
    }

    /// @notice Get all buy offers with data for single fiat
    /// @param _fiat Fiat address
    /// @param _offset Start index
    /// @param _limit Results limit. Zero for no limit
    /// @return array of Offer struct
    function getFiatBuyOffers(address _fiat, uint _offset, uint _limit) public view returns(Offer[] memory) {
        return _getOffersData(_buyOffers[_fiat], _offset, _limit);
    }

    /// @notice Get all sell offers with data for single fiat
    /// @param _fiat Fiat address
    /// @param _offset Start index
    /// @param _limit Results limit. Zero for no limit
    /// @return array of Offer struct
    function getFiatSellOffers(address _fiat, uint _offset, uint _limit) public view returns(Offer[] memory) {
        return _getOffersData(_sellOffers[_fiat], _offset, _limit);
    }

    function _getOffersData(
        address[] storage _array,
        uint _offset,
        uint _limit
        ) private view returns(Offer[] memory) {
        uint length = _array.length - _offset;
        uint offersCount = (_limit > 0 && _limit < length)
            ? _limit
            : length;
        Offer[] memory offers = new Offer[](offersCount);
        unchecked {
            for (uint i = _offset; i < _offset + offersCount; i++) {
                offers[i] = _getOfferData(_array[i]);
            }
        }
        return offers;
    }

    function _getOfferData(address _offerAddress) private view returns(Offer memory) {
        (
            address offerAddress,
            address fiatAddress,
            address ownerAddress,
            bool isBuy,
            bool isActive,
            uint commission,
            uint totalCommission,
            uint minTrade,
            uint maxTrade,
            uint tradesQuote
        ) = IOffer(_offerAddress).getOffer();
        return Offer({
            offerAddress: offerAddress,
            fiatAddress: fiatAddress,
            ownerAddress: ownerAddress,
            isBuy: isBuy,
            isActive: isActive,
            commission: commission,
            totalCommission: totalCommission,
            minTrade: minTrade,
            maxTrade: maxTrade,
            tradesQuote: tradesQuote
        });
    }

    /// @notice Get is account in the global platform blacklist
    /// @param _client Account address
    /// @return Is blacklisted
    function getIsBlacklisted(address _client) public view returns(bool) {
        return kyc.getIsBlacklisted(_client);
    }

    /// @notice Get is validator can trade
    /// @param _validator Account address
    /// @return Is can create offers and receive new trades
    function getCanTrade(address _validator) public view returns(bool) {
        return kyc.getCanTrade(_validator);
    }

    /// @notice Get validator fiat limit
    /// @param _validator Account address
    /// @param _fiatAddress Fiat
    /// @return Limit amount
    function getValidatorLimit(address _validator, address _fiatAddress) external view returns(uint) {
        return INarfexExchangerPool(router.getPool()).getValidatorLimit(_validator, _fiatAddress);
    }

    /// @notice Get protocol fee for a single fiat
    /// @param _fiatAddress Fiat
    /// @return Fee in precents
    function getFiatFee(address _fiatAddress) external view returns(uint) {
        return _fees[_fiatAddress];
    }

    /// @notice Get is account verified
    /// @param _client Account address
    /// @return Is verified
    function isKYCVerified(address _client) external view returns(bool) {
        return kyc.isKYCVerified(_client);
    }

    /// @notice How many trades can exist in an offer at the same time
    /// @return Limit amount
    function getTradesLimit() external view returns(uint) {
        return tradesLimit;
    }

    /// @notice Get token price in ETH (or BNB for BSC and etc.)
    /// @param _token Token address
    /// @return Token price
    /// @dev To estimate the gas price in fiat
    function getETHPrice(address _token) external view returns(uint) {
        INarfexOracle oracle = INarfexOracle(router.getOracle());
        return oracle.getPrice(_token) * ETH_PRECISION / oracle.getPrice(WETH);
    }

    /// @notice Randomly get the address of an active lawyer
    /// @return Lawyer account address
    function getLawyer() external view returns(address) {
        return lawyers.getLawyer();
    }

    /// @notice Get router address
    /// @return Router address
    function getRouter() external view returns(address) {
        return address(router);
    }

    /// Admin setters

    function setFiatFee(address _fiatAddress, uint16 _fee) public onlyOwner {
        _fees[_fiatAddress] = _fee;
        emit SetFiatFee(_fiatAddress, _fee);
    }
    function setRouter(address _router) public onlyOwner {
        require(address(router) != _router, "The same router");
        router = INarfexP2pRouter(_router);
        emit SetRouter(_router);
    }
    function setKYCContract(address _newAddress) public onlyOwner {
        require(address(kyc) != _newAddress, "The same address");
        kyc = INarfexKYC(_newAddress);
        emit SetKYCContract(_newAddress);
    }
    function setLawyersContract(address _newAddress) public onlyOwner {
        require(address(lawyers) != _newAddress, "The same address");
        lawyers = INarfexLawyers(_newAddress);
        emit SetLawyersContract(_newAddress);
    }
    function setTradesLimit(uint _limit) public onlyOwner {
        tradesLimit = _limit;
        emit SetTradesLimit(_limit);
    }
}