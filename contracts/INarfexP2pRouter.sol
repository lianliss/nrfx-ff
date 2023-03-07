//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

interface INarfexP2pRouter {
    function payFee(address _fiatAddress, uint _fiatAmount) external;
    function swapToETH(address to, address token, uint amount) external;
    function getPool() external view returns(address);
    function getOracle() external view returns(address);
}