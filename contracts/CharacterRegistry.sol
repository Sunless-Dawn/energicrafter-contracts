// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Characters.sol";
import "./Skills.sol";

// Main registry that coordinates the system
contract EnergiCrafterRegistry is Ownable {
    EnergiCrafterCharacters public characters;
    EnergiCrafterSkills public skills;
    
    constructor(address _signer) Ownable(msg.sender) {
        characters = new EnergiCrafterCharacters(address(this));
        skills = new EnergiCrafterSkills(_signer, address(this));
    }
    
    // Called by Characters contract when transferring
    function transferCharacterSkills(
        uint256 characterId, 
        address from,
        address to
    ) external {
        require(msg.sender == address(characters), "Only characters contract");
        skills.transferWithCharacter(characterId, from, to);
    }
    
    // Called to learn new skills
    function learnSkill(uint256 characterId, uint256 skillType) external {
        require(
            characters.ownerOf(characterId) == msg.sender,
            "Not character owner"
        );
        skills.learnSkill(EnergiCrafterSkills.LearnSkillParams({
            characterId: characterId,
            skillType: skillType,
            nonce: 0,
            signature: ""
        }));
    }
    
    function hasSkill(uint256 characterId, uint256 skillType) external view returns (bool) {
        return skills.hasSkill(characterId, skillType);
    }
}