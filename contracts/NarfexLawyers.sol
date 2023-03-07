//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Lawyers list for Narfex P2P service
/// @author Danil Sakhinov
contract NarfexLawyers is Ownable {

    struct Lawyer {
        bool isActive;
        bool[7][24] schedule;
    }

    address public writer;
    mapping (address=>Lawyer) private _lawyers;
    mapping (address=>bool) private _isLawyer;
    address[] public list;
    uint constant DAY = 86400;

    constructor() {
        setWriter(msg.sender);
    }

    event SetWriter(address _account);
    event Add(address _account);
    event Remove(address _account);

    modifier canWrite() {
        require(_msgSender() == owner() || _msgSender() == writer, "No permission");
        _;
    }
    modifier onlyWriter() {
        require(_msgSender() == writer, "Only writer can do it");
        _;
    }
    modifier onlyLawyer() {
        require(getIsLawyer(_msgSender()), "You are not Narfex lawyer");
        _;
    }

    /// @notice Set writer account
    /// @param _account New writer account address
    function setWriter(address _account) public onlyOwner {
        writer = _account;
        emit SetWriter(_account);
    }

    /// @notice Add account to the lawyers list
    /// @param _account Account address
    function add(address _account) public canWrite {
        require(!_isLawyer[_account], "Account is already lawyer");
        bool[7][24] memory schedule;
        unchecked {
            for (uint8 w; w < 7; w++) {
                for (uint8 h; h < 24; h++) {
                    schedule[w][h] = true;
                }
            }
        }
        _isLawyer[_account] = true;
        _lawyers[_account] = Lawyer({
            isActive: true,
            schedule: schedule
        });
        list.push(_account);
        emit Add(_account);
    }

    /// @notice Remove account from the lawyers list
    /// @param _account Lawyer address
    function remove(address _account) private canWrite {
        require(_isLawyer[_account], "Account is not lawyer");
        unchecked {
            uint j;
            for (uint i; i < list.length - 1; i++) {
                if (list[i] == _account) {
                    j++;
                }
                if (j > 0) {
                    list[i] = list[i + 1];
                }
            }
            if (j > 0) {
                list.pop();
                _isLawyer[_account] = false;
            }
        }
        emit Remove(_account);
    }

    /// @notice Get lawyer activity schedule
    /// @param _account Lawyer address
    /// @return Schedule
    function getSchedule(address _account) public view returns(bool[7][24] memory) {
        return _lawyers[_account].schedule;
    }

    /// @notice Set a new lawyer's schedule
    /// @param _schedule [weekDay][hour] => isActive
    function setSchedule(bool[7][24] calldata _schedule) public onlyLawyer {
        _lawyers[msg.sender].schedule = _schedule;
    }

    /// @notice Exclude or include a lawyer from the issuance 
    /// @param _newState New isActive state 
    function setIsActive(bool _newState) public onlyLawyer {
        _lawyers[msg.sender].isActive = _newState;
    }

    /// @notice Check if account is Protocol lawyer
    /// @param _account Account address
    /// @return Is lawyer
    function getIsLawyer(address _account) public view returns(bool) {
        return _isLawyer[_account];
    }

    /// @notice Return is lawyer active now
    /// @param _account Account address
    /// @return isActive Is lawyer active at this time
    function getIsActive(address _account) public view returns(bool isActive) {
        Lawyer memory lawyer;
        if (getIsLawyer(_account)) return false;
        if (!lawyer.isActive) return false;
        uint8 weekDay = uint8((block.timestamp / DAY + 4) % 7);
        uint8 hour = uint8((block.timestamp / 60 / 60) % 24);
        return lawyer.schedule[weekDay][hour];
    }

    /// @notice Get currently active lawyers
    /// @return Array of addresses
    function getActiveLawyers() private view returns(address[] memory, uint) {
        uint i;
        address[] memory active = new address[](list.length);
        unchecked {
            for (uint j; j < list.length; j++) {
                if (getIsActive(list[j])) {
                    active[i++] = list[j];
                }
            }
        }
        return (active, i);
    }

    /// @notice Randomly returns the currently available lawyer
    /// @return Active lawyer address
    function getLawyer() public view returns(address) {
        (address[] memory active, uint length) = getActiveLawyers();
        if (length == 0) return address(0);
        uint index = uint(keccak256(abi.encodePacked(block.timestamp, block.basefee))) % length;
        return active[index];
    }
}