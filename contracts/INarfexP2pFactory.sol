//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

interface INarfexP2pFactory {
    function getIsBlacklisted(address _client) external view returns(bool);
    function getValidatorLimit(address _validator, address _fiatAddress) external view returns(uint);
    function getFiatFee(address _fiatAddress) external view returns(uint);
    function isKYCVerified(address _client) external view returns(bool);
    function getTradesLimit() external view returns(uint);
    function getETHPrice(address _token) external view returns(uint);
    function getLawyer() external view returns(address);
    function getRouter() external view returns(address);
    function getCanTrade(address _validator) external view returns(bool);
}