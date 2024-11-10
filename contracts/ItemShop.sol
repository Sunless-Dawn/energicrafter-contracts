// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

interface IItemShop {
    struct ItemPrice {
        uint256 buyPrice;
        uint256 sellPrice;
    }
    
    function itemPrices(uint256 tokenId) external view returns (uint256 buyPrice, uint256 sellPrice);
    function setPricesForNewItem(uint256 tokenId, uint256 buyPrice, uint256 sellPrice) external;
}

contract ItemShop is IItemShop, Ownable, ERC1155Holder {
    IERC1155 public immutable gameToken;
    mapping(uint256 => ItemPrice) public itemPrices;
    
    event PricesSet(uint256 indexed tokenId, uint256 buyPrice, uint256 sellPrice);
    event ItemsSold(address indexed seller, uint256 indexed tokenId, uint256 amount, uint256 price);
    event ItemsBought(address indexed buyer, uint256 indexed tokenId, uint256 amount, uint256 price);
    
    constructor(address _gameToken) Ownable(msg.sender) {
        gameToken = IERC1155(_gameToken);
    }
    
    // Owner functions for base resources
    function setPrices(
        uint256 tokenId,
        uint256 buyPrice,
        uint256 sellPrice
    ) external onlyOwner {
        require(sellPrice > buyPrice, "Invalid spread");
        itemPrices[tokenId] = ItemPrice(buyPrice, sellPrice);
        emit PricesSet(tokenId, buyPrice, sellPrice);
    }
    
    function withdraw(uint256 amount) external onlyOwner {
        require(
            address(this).balance >= amount,
            "Insufficient balance"
        );
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
    
    // Called by game contract for newly crafted items
    function setPricesForNewItem(
        uint256 tokenId,
        uint256 buyPrice,
        uint256 sellPrice
    ) external {
        require(msg.sender == address(gameToken), "Only game contract");
        require(sellPrice > buyPrice, "Invalid spread");
        
        ItemPrice memory existingPrice = itemPrices[tokenId];
        if (existingPrice.sellPrice > 0) {
            require(
                sellPrice >= existingPrice.sellPrice && 
                buyPrice >= existingPrice.buyPrice,
                "Cannot lower existing prices"
            );
        }
        
        itemPrices[tokenId] = ItemPrice(buyPrice, sellPrice);
        emit PricesSet(tokenId, buyPrice, sellPrice);
    }
    
    // Trading functions
    function sellToShop(uint256 tokenId, uint256 amount) external {
        ItemPrice memory price = itemPrices[tokenId];
        require(price.buyPrice > 0, "Item not buyable");
        
        uint256 total = price.buyPrice * amount;
        require(address(this).balance >= total, "Insufficient shop balance");
        
        gameToken.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        
        (bool success, ) = msg.sender.call{value: total}("");
        require(success, "Transfer failed");
        
        emit ItemsSold(msg.sender, tokenId, amount, total);
    }
    
    function buyFromShop(uint256 tokenId, uint256 amount) external payable {
        ItemPrice memory price = itemPrices[tokenId];
        require(price.sellPrice > 0, "Item not for sale");
        require(msg.value == price.sellPrice * amount, "Incorrect payment");
        
        require(
            gameToken.balanceOf(address(this), tokenId) >= amount,
            "Insufficient shop inventory"
        );
        
        gameToken.safeTransferFrom(address(this), msg.sender, tokenId, amount, "");
        
        emit ItemsBought(msg.sender, tokenId, amount, msg.value);
    }
    
    // View functions
    function getPrice(uint256 tokenId) external view returns (ItemPrice memory) {
        return itemPrices[tokenId];
    }
}
