//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface INarfexP2pRouter {
    function swapTo(
        address to,
        address[] memory path,
        bool isExactOut,
        uint amount,
        uint amountLimit,
        uint deadline) external payable;
}

/// @title Exchanger pool for a single token
/// @author Danil Sakhinov
/// @dev Router have full access to the funds
contract NarfexExchangerPool is Ownable {
    using Address for address;

    IERC20 immutable token;
    address immutable NRFX;
    address public router;
    address public masterChef;
    mapping(address => mapping(address => uint)) public validatorLimit;
    uint private feeAmount;

    uint256 constant MAX_INT = type(uint).max;

    event SetRouter(address routerAddress);
    event Withdraw(address recipient, uint amount);
    event SetMasterChef(address masterChef);
    event IncreaseValidatorLimit(address indexed validator, address fiat, uint amount);
    event DecreaseValidatorLimit(address indexed validator, address fiat, uint amount);
    event WithdrawFee(uint feeAmount);

    constructor (
        address _token,
        address _routerAddress,
        address _nrfxAddress,
        address _masterChefAddress
        ) {
        token = IERC20(_token);
        router = _routerAddress;
        NRFX = _nrfxAddress;
        masterChef = _masterChefAddress;
        emit SetRouter(_routerAddress);
        emit SetMasterChef(_masterChefAddress);
    }

    /// @notice only factory owner and router have full access
    modifier fullAccess {
        require(isHaveFullAccess(_msgSender()), "You have no access");
        _;
    }

    /// @notice Returns the router address
    /// @return Router address
    function getRouter() public view returns (address) {
        return router;
    }

    /// @notice Returns the current token balance in this pool
    /// @return Amount of available tokens
    function getBalance() public view returns (uint) {
        return token.balanceOf(address(this));
    }

    /// @notice Sets the router address and approve token maximum amount to a new router
    /// @param _routerAddress Router address
    /// @dev Removes allowance from the old router
    function setRouter(address _routerAddress) public onlyOwner {
        require (_routerAddress != router, "The same router");
        token.approve(router, 0); /// Remove allowance
        router = _routerAddress;
        approveRouter(); /// Set maximum token allowance
        emit SetRouter(_routerAddress);
    }

    function setMasterChef(address _masterChefAddress) public onlyOwner {
        require (_masterChefAddress != masterChef, "The same MasterChef");
        masterChef = _masterChefAddress;
        emit SetMasterChef(_masterChefAddress);
    }

    /// @notice Returns true if the specified address have full access to user funds management
    /// @param account Account address
    /// @return Boolean
    function isHaveFullAccess(address account) internal view returns (bool) {
        return account == owner() || account == getRouter();
    }

    /// @notice Approve maximum token amount to the router
    /// @dev can be called by owner and router
    function approveRouter() public fullAccess {
        token.approve(router, MAX_INT);
    }

    /// @notice Withdraw tokens to the owner
    /// @param _amount Amount of tokens to withdraw
    function withdraw(uint _amount) public onlyOwner {
        token.transfer(_msgSender(), _amount);
        emit Withdraw(_msgSender(), _amount);
    }

    /// @notice Withdraw another tokens to the owner
    /// @param _amount Amount of tokens to withdraw
    /// @param _address Another token contract
    function withdraw(uint _amount, address _address) public onlyOwner {
        require(_address != address(token), "Withdraw this token without specifying an address");
        IERC20(_address).transfer(_msgSender(), _amount);
    }

    function increaseLimit(address _validator, address _fiatAddress, uint _amount) external fullAccess {
        validatorLimit[_validator][_fiatAddress] += _amount;
        emit IncreaseValidatorLimit(_validator, _fiatAddress, _amount);
    }

    function decreaseLimit(address _validator, address _fiatAddress, uint _amount) external fullAccess {
        require (getValidatorLimit(_validator, _fiatAddress) >= _amount, "Requested amount is more than validator pool amount");
        validatorLimit[_validator][_fiatAddress] -= _amount;
        emit DecreaseValidatorLimit(_validator, _fiatAddress, _amount);
    }

    function getValidatorLimit(address _validator, address _fiatAddress) public view returns(uint) {
        return validatorLimit[_validator][_fiatAddress];
    }

    function getFeeAmount() external view returns(uint) {
        return feeAmount;
    }

    function increaseFeeAmount(uint _amount) external fullAccess {
        feeAmount += _amount;
    }

    function sendFeeToMasterChef() public fullAccess {
        if (feeAmount == 0) return;
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = NRFX;
        INarfexP2pRouter(router).swapTo(
            masterChef,
            path,
            false,
            feeAmount,
            0,
            block.timestamp + 20 minutes
        );
        feeAmount = 0;
        emit WithdrawFee(feeAmount);
    }
}