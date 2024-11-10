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

    // Two special skills that are at the root
    uint256 public constant ITEM_CRAFT = 1;
    uint256 public constant SKILL_CRAFT = 2;

    // Add new mapping to track skills per character
    mapping(uint256 => uint256[]) private characterSkills; // characterId -> skillInstanceIds[]

    constructor(address _registry) ERC1155("https://assets.energicrafter.com/metadata/skills/{id}.json") {
        registry = EnergiCrafterRegistry(_registry);
    }

    function learnSkill(
        uint256 characterId,
        address owner,
        uint256 skillType
    ) external {
        require(msg.sender == address(registry), "Only registry");

        uint256 instanceId = (skillType << 128) | nextSkillInstance[skillType]++;
        _mint(owner, instanceId, 1, "");
        skillCharacter[instanceId] = characterId;

        // Add skill to character's skill list
        characterSkills[characterId].push(instanceId);
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
        return characterSkills[characterId];
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

    // every new character gets these two skills
    function mintInitialSkills(uint256 characterId, address owner) external {
        require(msg.sender == address(registry), "Only registry");

        // Mint ITEM_CRAFT skill
        uint256 itemCraftId = (ITEM_CRAFT << 128) | nextSkillInstance[ITEM_CRAFT]++;
        _mint(owner, itemCraftId, 1, "");
        skillCharacter[itemCraftId] = characterId;
        characterSkills[characterId].push(itemCraftId);

        // Mint SKILL_CRAFT skill
        uint256 skillCraftId = (SKILL_CRAFT << 128) | nextSkillInstance[SKILL_CRAFT]++;
        _mint(owner, skillCraftId, 1, "");
        skillCharacter[skillCraftId] = characterId;
        characterSkills[characterId].push(skillCraftId);
    }
}