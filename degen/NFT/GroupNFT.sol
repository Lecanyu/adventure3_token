// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../DegenMaster.sol";


contract GroupNFT is ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    address private _owner;


    DegenMaster private _degenMaster;

    constructor(string memory name, string memory symbol, address degenMasterAddr) ERC721(name, symbol) {
        _owner = msg.sender;
        _degenMaster = DegenMaster(degenMasterAddr);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function safeMint(address to) public onlyOwner returns (uint256 tid){
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);

        return tokenId;
    }
}



