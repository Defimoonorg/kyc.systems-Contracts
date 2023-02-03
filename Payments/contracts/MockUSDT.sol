// SPDX-License-Identifier: MIT
//
// Token contract interface

pragma solidity ^0.8.9;

interface IERC20 {
  function        balanceOf(address account) external view returns (uint256);
  function        transferFrom(address from,
                               address to,
                               uint256 amount
                               ) external returns (bool);
  function        transfer(address to, uint256 amount) external returns (bool);
  function        approve(address spender, uint256 amount) external returns (bool);
  function        allowance(address owner, address spender) external view returns (uint256);
}