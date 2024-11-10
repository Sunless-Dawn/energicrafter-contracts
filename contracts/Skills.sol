// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./CharacterRegistry.sol";

contract EnergiCrafterSkills is ERC1155 {
    EnergiCrafterRegistry immutable public registry;
    
    // Track which character owns each skill instance
    mapping(uint256 => uint256) public skillCharacter; // skillInstance -> characterId
    
    // Track the next instance ID for each skill type
    mapping(uint256 => uint256) private nextSkillInstance;
    
    constructor(address _registry) ERC1155("https://assets.energicrafter.com/metadata/skills/{id}.json") {
        registry = EnergiCrafterRegistry(_registry);
    }
    
    function learnSkill(
        uint256 characterId, 
        address owner,
        uint256 skillType
    ) external {
        require(msg.sender == address(registry), "Only registry");
        
        // Create a unique instance ID for this skill
        uint256 instanceId = (skillType << 128) | nextSkillInstance[skillType]++;
        
        // Mint the skill token to the character's owner
        _mint(owner, instanceId, 1, "");
        
        // Record which character this skill belongs to
        skillCharacter[instanceId] = characterId;
    }
    
    function transferWithCharacter(
        uint256 characterId,
        address from,
        address to
    ) external {
        require(msg.sender == address(registry), "Only registry");
        
        // Find and transfer all skills owned by this character
        uint256[] memory owned = getCharacterSkills(characterId);
        for(uint256 i = 0; i < owned.length; i++) {
            uint256 instanceId = owned[i];
            _safeTransferFrom(from, to, instanceId, 1, "");
        }
    }
    
    // Override transfer functions to prevent direct transfers
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            msg.sender == address(registry),
            "Skills can only be transferred with character"
        );
        super.safeTransferFrom(from, to, id, amount, data);
    }
    
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            msg.sender == address(registry),
            "Skills can only be transferred with character"
        );
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
    
    function getCharacterSkills(uint256 characterId) public view returns (uint256[] memory) {
        // Implementation would need to track and return all skills for a character
        // Could use events or additional mapping to track this efficiently
    }
    
    function hasSkill(uint256 characterId, uint256 skillType) public view returns (bool) {
        uint256[] memory skills = getCharacterSkills(characterId);
        for(uint256 i = 0; i < skills.length; i++) {
            if((skills[i] >> 128) == skillType) {
                return true;
            }
        }
        return false;
    }
}