// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC777/ERC777.sol";


contract GLDToken is ERC777 {
    constructor(uint256 initialSupply, address[] memory defaultOperators)
        public
        ERC777("Gold", "GLD", defaultOperators)
    {
        _mint(msg.sender, initialSupply, "", "");
    }
}


