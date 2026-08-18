// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AuctionData} from "./AuctionTypes.sol";
import "./AuctionEvents.sol";
import "./AuctionErrors.sol";

contract Auction is ReentrancyGuard  {
    uint256 private nextAuctionId;

    mapping(uint256 => AuctionData) private auctions;

    mapping(uint256 => mapping(address => uint256))private refundable;

    mapping(uint256 => uint256) private sellerBalances;

    uint256 private platformFeeBps = 200;
    uint256 private platformBalance;

    address private owner;
    uint256 private constant ANTI_SNIPE_TIME = 5 minutes;
    uint256 private constant ANTI_SNIPE_EXTENSION = 5 minutes;

    mapping(address => bool) private organizers;
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }

        _;
    }

    modifier onlyOrganizer() {
        if (!organizers[msg.sender]) {
            revert NotOrganizer();
        }

        _;
    }

    function addOrganizer(address account) external onlyOwner {
        if (account == address(0)) {
            revert ZeroAddress();
        }   

        organizers[account] = true;
    }
    
    function removeOrganizer(address account) external onlyOwner {
        organizers[account] = false;
    }

    function createAuction(
        string calldata metadataCID,
        uint256 startPrice,
        uint256 minimumIncrement,
        uint256 endTime
    ) external onlyOrganizer returns (uint256) {
        if (startPrice == 0) {
            revert InvalidStartPrice();
        }

        if (minimumIncrement == 0) {
            revert InvalidMinimumIncrement();
        }

        if (endTime <= block.timestamp) {
            revert InvalidEndTime();
        }
        if (bytes(metadataCID).length == 0) {
            revert EmptyMetadataCID();
        }
        nextAuctionId++;
        
        auctions[nextAuctionId] = AuctionData({
            id: nextAuctionId,
            seller: msg.sender,
            metadataCID: metadataCID,
            startPrice: startPrice,
            minimumIncrement: minimumIncrement,
            highestBid: 0,
            highestBidder: address(0),
            startTime: block.timestamp,
            endTime: endTime,
            active: true
        });

        emit AuctionCreated(
            nextAuctionId,
            msg.sender,
            metadataCID,
            startPrice,
            minimumIncrement,
            endTime
        );
        return nextAuctionId;
    }

    function placeBid(uint256 auctionId) external payable{
        AuctionData storage auction = auctions[auctionId];
        if (auction.id == 0) {
           revert AuctionNotFound();
        }
        if (!auction.active) {
           revert AuctionNotActive();
        }
        if (block.timestamp >= auction.endTime) {
            revert AuctionEnded();
        }

        uint256 requiredBid;

        if (auction.highestBid == 0) {
            requiredBid = auction.startPrice;
        } 
        else {
            requiredBid = auction.highestBid + auction.minimumIncrement;
        }

        if (msg.value < requiredBid) {
            revert BidTooLow();
        }

        if (auction.highestBidder != address(0)) {
            refundable[auctionId][auction.highestBidder] += auction.highestBid;
        }

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        if (auction.endTime - block.timestamp < ANTI_SNIPE_TIME) {
           auction.endTime += ANTI_SNIPE_EXTENSION;
        }

        emit BidPlaced(
            auctionId,
            msg.sender,
            msg.value,
            auction.endTime
        );
    }

    function withdrawBid(uint256 auctionId) external nonReentrant {
        uint256 amount = refundable[auctionId][msg.sender];

        if (amount == 0) {
            revert NothingToWithdraw();
        }

        refundable[auctionId][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");

        if (!success) {
            revert TransferFailed();
        }

        emit BidWithdrawn(
            auctionId,
            msg.sender,
            amount
        );
    }

    function finalizeAuction(uint256 auctionId) external {
        AuctionData storage auction = auctions[auctionId];

        if (auction.id == 0) {
            revert AuctionNotFound();
        }

        if (!auction.active) {
            revert AuctionAlreadyFinished();
        }

        if (block.timestamp < auction.endTime) {
            revert AuctionNotEnded();
        }

        auction.active = false;

        if (auction.highestBid == 0) {
            emit AuctionFinalized(
                auctionId,
                address(0),
                0,
                0,
                0
            );

            return;
        }

        uint256 platformFee = (auction.highestBid * platformFeeBps) / 10000;

        uint256 sellerAmount = auction.highestBid - platformFee;

        sellerBalances[auctionId] += sellerAmount;

        platformBalance += platformFee;

        emit AuctionFinalized(
            auctionId,
            auction.highestBidder,
            auction.highestBid,
            sellerAmount,
            platformFee
        );
    }

    function withdrawSellerFunds(uint256 auctionId) external nonReentrant
    {
        AuctionData storage auction = auctions[auctionId];

        if (auction.id == 0) {
            revert AuctionNotFound();
        }

        if (msg.sender != auction.seller) {
            revert NotSeller();
        }

        uint256 amount = sellerBalances[auctionId];

        if (amount == 0) {
            revert NothingToWithdraw();
        }

        sellerBalances[auctionId] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");

        if (!success) {
            revert TransferFailed();
        }

        emit SellerFundsWithdrawn(
            auctionId,
            msg.sender,
            amount
        );
    }
    function withdrawPlatformFees() external onlyOwner nonReentrant
    {
        uint256 amount = platformBalance;

        if (amount == 0) {
            revert NothingToWithdraw();
        }

        platformBalance = 0;

        (bool success, ) = payable(owner).call{value: amount}("");

        if (!success) {
            revert TransferFailed();
        }

        emit PlatformFeesWithdrawn(
            owner,
            amount
        );
    }

    function getAuction(uint256 auctionId) external view returns (AuctionData memory) {
        if (auctions[auctionId].id == 0) {
            revert AuctionNotFound();
        }

        return auctions[auctionId];
    }
    
    function getRefundable(uint256 auctionId, address bidder) external view returns (uint256) {
        return refundable[auctionId][bidder];
    }

    function getMyRefundable( uint256 auctionId ) external view returns (uint256) {
        return refundable[auctionId][msg.sender];
    }

    function getSellerBalance(uint256 auctionId) external view returns (uint256) {
        AuctionData storage auction = auctions[auctionId];

        if (auction.id == 0) {
            revert AuctionNotFound();
        }

        if (msg.sender != auction.seller) {
            revert NotSeller();
        }

        return sellerBalances[auctionId];
    }
    
    function getPlatformBalance() external view onlyOwner returns (uint256)
    {
        return platformBalance;
    }

    function getAuctionCount() external view returns (uint256)
    {
        return nextAuctionId;
    }
}
