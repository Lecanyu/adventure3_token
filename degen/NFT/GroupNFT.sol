// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../DegenMaster.sol";


contract GroupNFT is ERC721, ERC721Burnable {
    using Counters for Counters.Counter;

    mapping(uint256 => bool) private _tokenId2Burnable;
    Counters.Counter private _tokenIdCounter;
    DegenMaster private _degenMaster;

    modifier onlyDegenMaster() {
        require(msg.sender == address(_degenMaster), "Ownable: caller must be the DegenMaster");
        _;
    }

    constructor(string memory name, string memory symbol, address degenMasterAddr) ERC721(name, symbol) {
        _degenMaster = DegenMaster(degenMasterAddr);
    }

    //****************
    // utils
    //****************
    function setBurnable(uint256 tokenId) 
        onlyDegenMaster
        public
    {
        _tokenId2Burnable[tokenId] = true;
    }

    function getBurnable(uint256 tokenId) public returns (bool) {
        return _tokenId2Burnable[tokenId];
    }


    //****************
    // NFT function
    //****************
    function safeMint(address to) 
        onlyDegenMaster 
        public 
        returns (uint256 tid)
    {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);

        return tokenId;
    }

    
    function burn(uint256 tokenId) public override {
        require(_tokenId2Burnable[tokenId], "This NFT does not allow to burn, please wait task end");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _burn(tokenId);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override {
        // normal transfer
        if(from != address(0) && to != address(0)){
            _degenMaster.nftTransferModifyStatus(from, to, firstTokenId);
        }
        // burn
        if(from != address(0) && to == address(0)){
            _degenMaster.payReward(firstTokenId, payable(from));  // pay tokenId reward to 'from' address
        }
    }
}



