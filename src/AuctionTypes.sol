// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct AuctionData {
    uint256 id;
    address seller;
    string metadataCID;

    uint256 startPrice;
    uint256 minimumIncrement;

    uint256 highestBid;
    address highestBidder;

    uint256 startTime;
    uint256 endTime;

    bool active;
}