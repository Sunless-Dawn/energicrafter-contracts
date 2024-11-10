// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IItemShop {
    struct ItemPrice {
        uint256 buyPrice;
        uint256 sellPrice;
    }
    
    function itemPrices(uint256 tokenId) external view returns (uint256 buyPrice, uint256 sellPrice);
    function setPricesForNewItem(uint256 tokenId, uint256 buyPrice, uint256 sellPrice) external;
}