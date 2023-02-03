//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    address public owner;

    constructor() ERC20("MockToken", "MT") {
      owner = msg.sender;
    }

    function mint(address _to, uint _amount) public {
        require(_to != address(0));
        require(_amount > 0);
        require(msg.sender == owner);

        _mint(_to, _amount);
    }

    function burn(address _from, uint _amount) public {
        require(_from != address(0));
        require(_amount > 0);
        require(msg.sender == owner);
        require(_amount <= balanceOf(_from));

        _burn(_from, _amount);
    }
}

