//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {

    constructor() ERC20("MockToken", "MT") {
    }

    function mint(address _to, uint _amount) public {
        require(_to != address(0));
        require(_amount > 0);

        _mint(_to, _amount);
    }

    function burn(address _from, uint _amount) public {
        require(_from != address(0));
        require(_amount > 0);
        require(_amount <= balanceOf(_from));

        _burn(_from, _amount);
    }
}

