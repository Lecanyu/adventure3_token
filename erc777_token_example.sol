// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract TestToken is ERC777 {
    
    event BeforeTokenTransfer(address indexed operator, address indexed from, address indexed to, uint256 amount, string log_text);

    constructor(
        uint256 initialSupply, 
        address[] memory defaultOperators
    ) ERC777("Test", "TTT", defaultOperators)
    {
        _mint(msg.sender, initialSupply, "", "");
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        emit BeforeTokenTransfer(operator, from, to, amount, "call method _beforeTokenTransfer");
    }
}


