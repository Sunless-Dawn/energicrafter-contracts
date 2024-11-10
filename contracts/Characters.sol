// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CharacterRegistry.sol";

contract EnergiCrafterCharacters is ERC721, Ownable {
    EnergiCrafterRegistry immutable public registry;
    string private _baseTokenURI;

    uint256 private _nextTokenId = 1;

    constructor(address _registry) ERC721("EnergiCrafter Characters", "ECHAR") Ownable(msg.sender) {
        registry = EnergiCrafterRegistry(_registry);
        _baseTokenURI = "https://assets.energicrafter.com/metadata/characters/{id}.json";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
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

    function mint(address to) external returns (uint256) {
        require(msg.sender == address(registry), "Only registry can mint");

        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }
}