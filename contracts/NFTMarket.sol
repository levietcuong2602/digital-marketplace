// contracts/NFTMarket.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract NFTMarket is ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    address payable owner;
    uint256 commission = 0.025 ether;

    constructor() {
        owner = payable(msg.sender);
    }

    struct SaleOrder {
        bytes32 orderId;
        address tokenAddress;
        uint256 tokenId;
        address payable seller;
        address payable buyer;
        uint256 price;
        bool sold;
    }

    mapping(bytes32 => SaleOrder) private saleOrdersById; // order id => sale order
    bytes32[] public saleOrderIds; // array of onsell order id
    uint256 public saleOrderIdLength;

    event Sell(
        bytes32 orderId,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );

    event Buy(
        bytes32 orderId,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price,
        uint256 pay
    );

    event Cancel(
        bytes32 orderId,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        uint256 price,
        address indexed seller
    );

    /* Returns the listing price of the contract */
    function getListingPrice() public view returns (uint256) {
        return commission;
    }

    function _transferToken(
        address tokenAddress,
        uint256 tokenId,
        address from,
        address to
    ) internal {
        IERC721(tokenAddress).transferFrom(from, to, tokenId);
    }

    /* Places an item for sale on the marketplace */
    function sell(
        address tokenAddress,
        uint256 tokenId,
        uint256 price
    ) external nonReentrant {
        require(price > 0, "Price must be at least 1 wei");

        address seller = msg.sender;
        bytes32 orderId = keccak256(
            abi.encodePacked(
                block.timestamp,
                tokenAddress,
                tokenId,
                price,
                seller
            )
        );

        SaleOrder memory sale = SaleOrder(
            orderId,
            tokenAddress,
            tokenId,
            payable(seller),
            payable(address(0)),
            price,
            false
        );

        _transferToken(tokenAddress, tokenId, msg.sender, address(this));

        saleOrdersById[sale.orderId] = sale;
        saleOrderIds.push(orderId);
        saleOrderIdLength = saleOrderIds.length;

        emit Sell(sale.orderId, tokenAddress, tokenId, msg.sender, price);
    }

    function removeOrderId(bytes32 orderId) internal {
        for (uint256 i = 0; i < saleOrderIds.length; i++) {
            if (saleOrderIds[i] == orderId) {
                saleOrderIds[i] = saleOrderIds[saleOrderIds.length - 1];
                saleOrderIds.pop();
                saleOrderIdLength = saleOrderIds.length;

                break;
            }
        }
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function buy(bytes32 orderId) public payable nonReentrant {
        require(orderId != 0, "not saling");

        SaleOrder memory sale = saleOrdersById[orderId];

        require(
            msg.value >= sale.price,
            "Please submit the asking price in order to complete the purchase"
        );

        _transferToken(
            sale.tokenAddress,
            sale.tokenId,
            address(this),
            msg.sender
        );

        saleOrdersById[orderId].buyer = payable(msg.sender);
        saleOrdersById[orderId].sold = true;

        removeOrderId(sale.orderId);
        delete saleOrdersById[sale.orderId];

        sale.seller.transfer(msg.value - commission);
        payable(owner).transfer(commission);

        emit Buy(
            sale.orderId,
            sale.tokenAddress,
            sale.tokenId,
            sale.seller,
            msg.sender,
            sale.price,
            msg.value
        );
    }

    /* Returns all unsold market items */
    function getOnSaleOrder() public view returns (SaleOrder[] memory) {
        SaleOrder[] memory items = new SaleOrder[](saleOrderIdLength);
        for (uint256 i = 0; i < saleOrderIdLength; i++) {
            bytes32 orderId = saleOrderIds[i];

            SaleOrder storage currentItem = saleOrdersById[orderId];
            items[i] = currentItem;
        }
        return items;
    }

    /* Returns only items that a user has purchased */
    function fetchMyNFTs() public view returns (SaleOrder[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (saleOrdersById[i + 1].buyer == msg.sender) {
                itemCount += 1;
            }
        }

        SaleOrder[] memory items = new SaleOrder[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (saleOrdersById[i + 1].buyer == msg.sender) {
                uint256 currentId = i + 1;
                SaleOrder storage currentItem = saleOrdersById[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items a user has created */
    function fetchItemsCreated() public view returns (SaleOrder[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (saleOrdersById[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        SaleOrder[] memory items = new SaleOrder[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (saleOrdersById[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                SaleOrder storage currentItem = saleOrdersById[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
