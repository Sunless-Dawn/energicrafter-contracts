// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./CharacterRegistry.sol";

contract EnergiCrafterCharacters is ERC721 {
    EnergiCrafterRegistry immutable public registry;
    
    constructor(address _registry) ERC721("EnergiCrafter Characters", "ECHAR") {
        registry = EnergiCrafterRegistry(_registry);
    }
    
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        super.transferFrom(from, to, tokenId);
        registry.transferCharacterSkills(tokenId, from, to);
    }
    
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        super.safeTransferFrom(from, to, tokenId, data);
        registry.transferCharacterSkills(tokenId, from, to);
    }
}