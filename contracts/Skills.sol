// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract EnergiCrafterSkills is ERC1155, Ownable {
    using ECDSA for bytes32;

    address public signerAddress;
    address public immutable registry;

    mapping(uint256 => uint256) public skillCharacter; // skillInstance -> characterId
    mapping(uint256 => uint256[]) private characterSkills; // characterId -> skillInstanceIds[]
    mapping(uint256 => uint256) public nextSkillInstance; // skillType -> nextInstanceId
    mapping(uint256 => bool) public globalSkills; // skillType -> exists in academy
    mapping(address => uint256) public nonces;

    // Two special skills that are at the root
    uint256 public constant ITEM_CRAFT = 1;
    uint256 public constant SKILL_CRAFT = 2;


    event SkillLearned(uint256 indexed characterId, uint256 skillType, uint256 instanceId);
    event NewSkillCrafted(uint256 indexed characterId, uint256 skillType);

    struct LearnSkillParams {
        uint256 characterId;
        uint256 skillType;
        uint256 nonce;
        bytes signature;
    }

    struct CraftSkillParams {
        uint256 characterId;
        uint256[] requiredSkillTypes; // skills required to craft this new skill
        uint256 newSkillType;
        uint256 nonce;
        bytes signature;
    }

    constructor(
        address _signer,
        address _registry
    ) ERC1155("https://assets.energicrafter.com/metadata/skills/{id}.json") Ownable(msg.sender) {
        signerAddress = _signer;
        registry = _registry;
    }

    function learnSkill(LearnSkillParams calldata params) external {
        require(params.nonce == nonces[msg.sender]++, "Invalid nonce");
        require(globalSkills[params.skillType], "Skill not available in academy");

        bytes32 messageHash = keccak256(abi.encodePacked(
            params.characterId,
            params.skillType,
            msg.sender,
            params.nonce
        ));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        require(ECDSA.recover(ethSignedMessageHash, params.signature) == signerAddress, "Invalid signature");

        _mintSkill(params.characterId, params.skillType);
    }

    function craftNewSkill(CraftSkillParams calldata params) external {
        require(params.nonce == nonces[msg.sender]++, "Invalid nonce");
        require(!globalSkills[params.newSkillType], "Skill already exists");

        // Verify character has all required skills
        for(uint i = 0; i < params.requiredSkillTypes.length; i++) {
            require(hasSkill(params.characterId, params.requiredSkillTypes[i]), "Missing required skill");
        }

        bytes32 messageHash = keccak256(abi.encodePacked(
            params.characterId,
            params.requiredSkillTypes,
            params.newSkillType,
            msg.sender,
            params.nonce
        ));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        require(ECDSA.recover(ethSignedMessageHash, params.signature) == signerAddress, "Invalid signature");

        // Add to global skills registry
        globalSkills[params.newSkillType] = true;

        // Mint the first instance to the crafter
        _mintSkill(params.characterId, params.newSkillType);

        emit NewSkillCrafted(params.characterId, params.newSkillType);
    }

    function _mintSkill(uint256 characterId, uint256 skillType) internal {
        uint256 instanceId = (skillType << 128) | nextSkillInstance[skillType]++;
        _mint(msg.sender, instanceId, 1, "");
        skillCharacter[instanceId] = characterId;
        characterSkills[characterId].push(instanceId);

        emit SkillLearned(characterId, skillType, instanceId);
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