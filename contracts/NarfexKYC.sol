//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title KYC verifications, validators and blacklist for Narfex P2P service
/// @author Danil Sakhinov
contract NarfexKYC is Ownable {

    mapping(address=>string) private _clients;
    mapping(address=>bool) private _verificators;
    mapping(address=>bool) private _blacklisted;
    address public writer;

    constructor() {
        setWriter(msg.sender);
    }

    event SetWriter(address _account);
    event Verify(address _account);
    event RevokeVerification(address _account);
    event AddVerificator(address _account);
    event RemoveVerificator(address _account);
    event Blacklisted(address _account);
    event Unblacklisted(address _account);

    modifier canWrite() {
        require(_msgSender() == owner() || _msgSender() == writer, "No permission");
        _;
    }
    modifier onlyWriter() {
        require(_msgSender() == writer, "Only writer can do it");
        _;
    }

    /// @notice Set writer account
    /// @param _account New writer account address
    function setWriter(address _account) public onlyOwner {
        writer = _account;
        emit SetWriter(_account);
    }

    /// @notice Is account verified
    /// @param _client Account address
    /// @return True if contract have personnel data for this account
    function isKYCVerified(address _client) public view returns(bool) {
        return bytes(_clients[_client]).length > 0;
    }

    /// @notice Verify the account
    /// @param _account Account address
    /// @param _data Encrypted JSON encoded account personnel data
    function verify(address _account, string calldata _data) public onlyWriter {
        require(bytes(_data).length > 0, "Data can't be empty");
        _clients[_account] = _data;
        emit Verify(_account);
    }

    /// @notice Clead account personnel data
    /// @param _account Account address
    function revokeVerification(address _account) public canWrite {
        _clients[_account] = '';
        emit RevokeVerification(_account);
    }

    /// @notice Get data in one request
    /// @param _accounts Array of addresses
    /// @return Array of strings
    function getData(address[] calldata _accounts) public view returns(string[] memory) {
        string[] memory data = new string[](_accounts.length);
        unchecked {
            for (uint i; i < _accounts.length; i++) {
                data[i] = _clients[_accounts[i]];
            }
        }
        return data;
    }

    /// @notice Mark account as verificator
    /// @param _account Account address
    function addVerificator(address _account) public onlyWriter {
        _verificators[_account] = true;
        emit AddVerificator(_account);
    }

    /// @notice Remove account from verificators list
    /// @param _account Account address
    function removeVerificator(address _account) public canWrite {
        _verificators[_account] = false;
        emit RemoveVerificator(_account);
    }

    /// @notice Add account to global Protocol blacklist
    /// @param _account Account address
    function addToBlacklist(address _account) public canWrite {
        _blacklisted[_account] = true;
        emit Blacklisted(_account);
    }

    /// @notice Remove account from global Protocol blacklist
    /// @param _account Account address
    function removeFromBlacklist(address _account) public canWrite {
        _blacklisted[_account] = false;
        emit Unblacklisted(_account);
    }

    /// @notice Return true if account is blacklisted
    /// @param _account Account address
    /// @return Is blacklisted
    function getIsBlacklisted(address _account) public view returns(bool) {
        return _blacklisted[_account];
    }
    
    /// @notice Return true if account verified and added to verificators list
    /// @param _account Account address
    /// @return Is can trade
    function getCanTrade(address _account) public view returns(bool) {
        return _verificators[_account] && !getIsBlacklisted(_account) && isKYCVerified(_account);
    }
}