// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

event AuctionCreated(
    uint256 indexed auctionId,
    address indexed seller,
    string metadataCID,
    uint256 startPrice,
    uint256 minimumIncrement,
    uint256 endTime
);

event BidPlaced(
    uint256 indexed auctionId,
    address indexed bidder,
    uint256 amount,
    uint256 newEndTime
);

event BidWithdrawn(
    uint256 indexed auctionId,
    address indexed bidder,
    uint256 amount
);

event AuctionFinalized(
    uint256 indexed auctionId,
    address indexed winner,
    uint256 winningBid,
    uint256 sellerAmount,
    uint256 platformFee
);

event SellerFundsWithdrawn(
    uint256 indexed auctionId,
    address indexed seller,
    uint256 amount
);

event PlatformFeesWithdrawn(
    address indexed owner,
    uint256 amount
);