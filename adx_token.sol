// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract ADXToken is ERC777 {
    constructor(
        uint256 initialSupply, 
        address[] memory defaultOperators
    ) ERC777("Adventure", "ADX", defaultOperators)
    {
        // 200000000000000000000000000
        _mint(msg.sender, initialSupply, "", "");
    }
}


