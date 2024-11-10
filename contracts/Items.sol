// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/ItemShop.sol";

contract EnergiCrafterItems is ERC1155, Ownable {
    using ECDSA for bytes32;

    address public signerAddress;
    IItemShop public shop;
    mapping(address => uint256) public nonces;
    uint256 public craftingFeePercent = 10; // 10% fee
    
    event CraftingFeeUpdated(uint256 newFee);
    event ItemCrafted(
        address indexed crafter,
        uint256[] inputTokenIds,
        uint256[] inputAmounts,
        uint256 outputTokenId,
        uint256 outputAmount,
        uint256 craftingFee
    );
    
    struct CraftingParams {
        uint256[] inputTokenIds;
        uint256[] inputAmounts;
        uint256 outputTokenId;
        uint256 outputAmount;
        uint256 nonce;
        bytes signature;
    }
    
    constructor(
        address _signer
    ) ERC1155("https://assets.energicrafter.com/metadata/items/{id}.json") Ownable(msg.sender) {
        signerAddress = _signer;
    }
    
    function setShop(address _shop) external onlyOwner {
        shop = IItemShop(_shop);
    }
    
    function setCraftingFee(uint256 _percent) external onlyOwner {
        require(_percent <= 50, "Fee too high"); // Max 50% fee
        craftingFeePercent = _percent;
        emit CraftingFeeUpdated(_percent);
    }

    function calculateInputCost(
        uint256[] calldata inputTokenIds,
        uint256[] calldata inputAmounts
    ) public view returns (uint256) {
        uint256 totalCost = 0;
        for(uint i = 0; i < inputTokenIds.length; i++) {
            (,uint256 sellPrice) = shop.itemPrices(inputTokenIds[i]);
            require(sellPrice > 0, "Input item not priced");
            totalCost += sellPrice * inputAmounts[i];
        }
        return totalCost;
    }

    function craftItem(CraftingParams calldata params) external payable {
        require(params.nonce == nonces[msg.sender]++, "Invalid nonce");
        
        bytes32 messageHash = keccak256(abi.encodePacked(
            params.inputTokenIds,
            params.inputAmounts,
            params.outputTokenId,
            params.outputAmount,
            msg.sender,
            params.nonce
        ));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        require(ECDSA.recover(ethSignedMessageHash, params.signature) == signerAddress, "Invalid signature");
        
        // Calculate and verify crafting fee
        uint256 inputCost = calculateInputCost(params.inputTokenIds, params.inputAmounts);
        uint256 craftingFee = (inputCost * craftingFeePercent) / 100;
        require(msg.value >= craftingFee, "Insufficient crafting fee");
        
        // Burn inputs
        for(uint i = 0; i < params.inputTokenIds.length; i++) {
            _burn(msg.sender, params.inputTokenIds[i], params.inputAmounts[i]);
        }
        
        // Mint output
        _mint(msg.sender, params.outputTokenId, params.outputAmount, "");
        
        // Calculate and set prices for new item
        uint256 newSellPrice = (inputCost + craftingFee) / params.outputAmount;
        uint256 newBuyPrice = (newSellPrice * 80) / 100; // 80% of sell price
        
        // Set prices in shop
        shop.setPricesForNewItem(params.outputTokenId, newBuyPrice, newSellPrice);
        
        // Send crafting fee to shop
        (bool success, ) = address(shop).call{value: craftingFee}("");
        require(success, "Fee transfer failed");
        
        emit ItemCrafted(
            msg.sender,
            params.inputTokenIds,
            params.inputAmounts,
            params.outputTokenId,
            params.outputAmount,
            craftingFee
        );
    }
}
