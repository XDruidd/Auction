// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Auction} from "../src/Auction.sol";
import {AuctionData} from "../src/AuctionTypes.sol";
import "../src/AuctionErrors.sol";

contract AuctionTest is Test {
    Auction public auction;

    address public owner = makeAddr("owner");
    address public organizer = makeAddr("organizer");
    address public seller = makeAddr("seller");
    address public bidder1 = makeAddr("bidder1");
    address public bidder2 = makeAddr("bidder2");
    address public stranger = makeAddr("stranger");

    uint256 public constant START_PRICE = 1 ether;
    uint256 public constant MIN_INCREMENT = 0.1 ether;

    uint256 public endTime;

    function setUp() public {
        vm.prank(owner);
        auction = new Auction();

        vm.prank(owner);
        auction.addOrganizer(organizer);

        endTime = block.timestamp + 1 hours;

        vm.deal(owner, 100 ether);
        vm.deal(organizer, 100 ether);
        vm.deal(seller, 100 ether);
        vm.deal(bidder1, 100 ether);
        vm.deal(bidder2, 100 ether);
        vm.deal(stranger, 100 ether);
    }

    // =============================================================
    //                         ORGANIZERS
    // =============================================================

    function testOwnerCanAddOrganizer() public {
        address newOrganizer = makeAddr("newOrganizer");

        vm.prank(owner);
        auction.addOrganizer(newOrganizer);

        vm.prank(newOrganizer);

        uint256 auctionId = auction.createAuction(
            "QmTestCID",
            START_PRICE,
            MIN_INCREMENT,
            endTime
        );

        assertEq(auctionId, 1);
    }

    function testNonOwnerCannotAddOrganizer() public {
        vm.prank(stranger);

        vm.expectRevert(NotOwner.selector);
        auction.addOrganizer(makeAddr("newOrganizer"));
    }

    function testCannotAddZeroAddressOrganizer() public {
        vm.prank(owner);

        vm.expectRevert(ZeroAddress.selector);
        auction.addOrganizer(address(0));
    }

    function testOwnerCanRemoveOrganizer() public {
        vm.prank(owner);
        auction.removeOrganizer(organizer);

        vm.prank(organizer);

        vm.expectRevert(NotOrganizer.selector);

        auction.createAuction(
            "QmTestCID",
            START_PRICE,
            MIN_INCREMENT,
            endTime
        );
    }

    function testNonOrganizerCannotCreateAuction() public {
        vm.prank(stranger);

        vm.expectRevert(NotOrganizer.selector);

        auction.createAuction(
            "QmTestCID",
            START_PRICE,
            MIN_INCREMENT,
            endTime
        );
    }

    // =============================================================
    //                       CREATE AUCTION
    // =============================================================

    function testCreateAuction() public {
        vm.prank(organizer);

        uint256 auctionId = auction.createAuction(
            "QmTestCID",
            START_PRICE,
            MIN_INCREMENT,
            endTime
        );

        assertEq(auctionId, 1);
        assertEq(auction.getAuctionCount(), 1);

        AuctionData memory data = auction.getAuction(auctionId);

        assertEq(data.id, 1);
        assertEq(data.seller, organizer);
        assertEq(data.metadataCID, "QmTestCID");
        assertEq(data.startPrice, START_PRICE);
        assertEq(data.minimumIncrement, MIN_INCREMENT);
        assertEq(data.highestBid, 0);
        assertEq(data.highestBidder, address(0));
        assertEq(data.startTime, block.timestamp);
        assertEq(data.endTime, endTime);
        assertTrue(data.active);
    }

    function testCreateMultipleAuctions() public {
        vm.startPrank(organizer);

        uint256 id1 = auction.createAuction(
            "CID-1",
            1 ether,
            0.1 ether,
            block.timestamp + 1 hours
        );

        uint256 id2 = auction.createAuction(
            "CID-2",
            2 ether,
            0.2 ether,
            block.timestamp + 2 hours
        );

        vm.stopPrank();

        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(auction.getAuctionCount(), 2);
    }

    function testCreateAuctionInvalidStartPrice() public {
        vm.prank(organizer);

        vm.expectRevert(InvalidStartPrice.selector);

        auction.createAuction(
            "QmTestCID",
            0,
            MIN_INCREMENT,
            endTime
        );
    }

    function testCreateAuctionInvalidMinimumIncrement() public {
        vm.prank(organizer);

        vm.expectRevert(InvalidMinimumIncrement.selector);

        auction.createAuction(
            "QmTestCID",
            START_PRICE,
            0,
            endTime
        );
    }

    function testCreateAuctionInvalidEndTime() public {
        vm.prank(organizer);

        vm.expectRevert(InvalidEndTime.selector);

        auction.createAuction(
            "QmTestCID",
            START_PRICE,
            MIN_INCREMENT,
            block.timestamp
        );
    }

    function testCreateAuctionEmptyCID() public {
        vm.prank(organizer);

        vm.expectRevert(EmptyMetadataCID.selector);

        auction.createAuction(
            "",
            START_PRICE,
            MIN_INCREMENT,
            endTime
        );
    }

    // =============================================================
    //                           BIDS
    // =============================================================

    function _createAuction() internal returns (uint256) {
        vm.prank(organizer);

        return auction.createAuction(
            "QmTestCID",
            START_PRICE,
            MIN_INCREMENT,
            block.timestamp + 1 hours
        );
    }

    function testPlaceFirstBid() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        AuctionData memory data = auction.getAuction(auctionId);

        assertEq(data.highestBid, 1 ether);
        assertEq(data.highestBidder, bidder1);
        assertTrue(data.active);

        assertEq(auction.getRefundable(auctionId, bidder1), 0);
    }

    function testFirstBidMustBeAtLeastStartPrice() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);

        vm.expectRevert(BidTooLow.selector);

        auction.placeBid{value: 0.9 ether}(auctionId);
    }

    function testSecondBidMustRespectMinimumIncrement() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        vm.prank(bidder2);

        vm.expectRevert(BidTooLow.selector);

        auction.placeBid{value: 1.05 ether}(auctionId);
    }

    function testSecondBidIsAccepted() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        vm.prank(bidder2);
        auction.placeBid{value: 1.1 ether}(auctionId);

        AuctionData memory data = auction.getAuction(auctionId);

        assertEq(data.highestBid, 1.1 ether);
        assertEq(data.highestBidder, bidder2);

        assertEq(
            auction.getRefundable(auctionId, bidder1),
            1 ether
        );
    }

    function testPreviousBidderCanWithdrawRefund() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        vm.prank(bidder2);
        auction.placeBid{value: 1.1 ether}(auctionId);

        uint256 balanceBefore = bidder1.balance;

        vm.prank(bidder1);
        auction.withdrawBid(auctionId);

        assertEq(
            bidder1.balance,
            balanceBefore + 1 ether
        );

        assertEq(
            auction.getRefundable(auctionId, bidder1),
            0
        );
    }

    function testCannotWithdrawRefundTwice() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        vm.prank(bidder2);
        auction.placeBid{value: 1.1 ether}(auctionId);

        vm.prank(bidder1);
        auction.withdrawBid(auctionId);

        vm.prank(bidder1);

        vm.expectRevert(NothingToWithdraw.selector);

        auction.withdrawBid(auctionId);
    }

    function testCannotWithdrawRefundWithoutRefund() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);

        vm.expectRevert(NothingToWithdraw.selector);

        auction.withdrawBid(auctionId);
    }

    function testCannotBidOnUnknownAuction() public {
        vm.prank(bidder1);

        vm.expectRevert(AuctionNotFound.selector);

        auction.placeBid{value: 1 ether}(999);
    }

    function testCannotBidAfterAuctionEnded() public {
        uint256 auctionId = _createAuction();

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(bidder1);

        vm.expectRevert(AuctionEnded.selector);

        auction.placeBid{value: 1 ether}(auctionId);
    }

    // =============================================================
    //                         ANTI SNIPE
    // =============================================================

    function testAntiSnipeExtendsAuction() public {
        uint256 auctionId = _createAuction();

        AuctionData memory beforeBid = auction.getAuction(auctionId);

        uint256 originalEndTime = beforeBid.endTime;

        vm.warp(originalEndTime - 2 minutes);

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        AuctionData memory afterBid = auction.getAuction(auctionId);

        assertEq(
            afterBid.endTime,
            originalEndTime + 5 minutes
        );
    }

    function testBidOutsideAntiSnipeWindowDoesNotExtend() public {
        uint256 auctionId = _createAuction();

        AuctionData memory data = auction.getAuction(auctionId);

        uint256 originalEndTime = data.endTime;

        vm.warp(originalEndTime - 10 minutes);

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        data = auction.getAuction(auctionId);

        assertEq(data.endTime, originalEndTime);
    }

    // =============================================================
    //                       FINALIZATION
    // =============================================================

    function testFinalizeAuctionWithWinner() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        AuctionData memory data = auction.getAuction(auctionId);

        vm.warp(data.endTime + 1);

        auction.finalizeAuction(auctionId);

        data = auction.getAuction(auctionId);

        assertFalse(data.active);
        assertEq(data.highestBid, 1 ether);
        assertEq(data.highestBidder, bidder1);

        // 2% fee
        // 1 ETH - 0.02 ETH = 0.98 ETH
        vm.prank(organizer);

        assertEq(
            auction.getSellerBalance(auctionId),
            0.98 ether
        );

        vm.prank(owner);

        assertEq(
            auction.getPlatformBalance(),
            0.02 ether
        );
    }

    function testFinalizeAuctionWithoutBids() public {
        uint256 auctionId = _createAuction();

        AuctionData memory data = auction.getAuction(auctionId);

        vm.warp(data.endTime + 1);

        auction.finalizeAuction(auctionId);

        data = auction.getAuction(auctionId);

        assertFalse(data.active);
        assertEq(data.highestBid, 0);
        assertEq(data.highestBidder, address(0));

        vm.prank(organizer);

        assertEq(
            auction.getSellerBalance(auctionId),
            0
        );

        vm.prank(owner);

        assertEq(
            auction.getPlatformBalance(),
            0
        );
    }

    function testCannotFinalizeBeforeEnd() public {
        uint256 auctionId = _createAuction();

        vm.expectRevert(AuctionNotEnded.selector);

        auction.finalizeAuction(auctionId);
    }

    function testCannotFinalizeTwice() public {
        uint256 auctionId = _createAuction();

        AuctionData memory data = auction.getAuction(auctionId);

        vm.warp(data.endTime + 1);

        auction.finalizeAuction(auctionId);

        vm.expectRevert(AuctionAlreadyFinished.selector);

        auction.finalizeAuction(auctionId);
    }

    function testCannotFinalizeUnknownAuction() public {
        vm.expectRevert(AuctionNotFound.selector);

        auction.finalizeAuction(999);
    }

    // =============================================================
    //                    SELLER WITHDRAW
    // =============================================================

    function testSellerCanWithdrawFunds() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        AuctionData memory data = auction.getAuction(auctionId);

        vm.warp(data.endTime + 1);

        auction.finalizeAuction(auctionId);

        uint256 sellerBalanceBefore = organizer.balance;

        vm.prank(organizer);
        auction.withdrawSellerFunds(auctionId);

        assertEq(
            organizer.balance,
            sellerBalanceBefore + 0.98 ether
        );

        // Проверяем, что после вывода баланс продавца равен 0
        vm.prank(organizer);
        assertEq(
            auction.getSellerBalance(auctionId),
            0
        );
    }

    function testNonSellerCannotWithdrawSellerFunds() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        AuctionData memory data = auction.getAuction(auctionId);

        vm.warp(data.endTime + 1);

        auction.finalizeAuction(auctionId);

        vm.prank(bidder1);

        vm.expectRevert(NotSeller.selector);

        auction.withdrawSellerFunds(auctionId);
    }

    function testSellerCannotWithdrawBeforeFinalization() public {
        uint256 auctionId = _createAuction();

        vm.prank(organizer);

        vm.expectRevert(NothingToWithdraw.selector);

        auction.withdrawSellerFunds(auctionId);
    }

    function testCannotWithdrawSellerFundsFromUnknownAuction() public {
        vm.prank(organizer);

        vm.expectRevert(AuctionNotFound.selector);

        auction.withdrawSellerFunds(999);
    }

    // =============================================================
    //                    PLATFORM FEES
    // =============================================================

    function testOwnerCanWithdrawPlatformFees() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        AuctionData memory data = auction.getAuction(auctionId);

        vm.warp(data.endTime + 1);

        auction.finalizeAuction(auctionId);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        auction.withdrawPlatformFees();

        assertEq(
            owner.balance,
            ownerBalanceBefore + 0.02 ether
        );

        vm.prank(owner);

        assertEq(
            auction.getPlatformBalance(),
            0
        );
    }

    function testNonOwnerCannotWithdrawPlatformFees() public {
        vm.prank(stranger);

        vm.expectRevert(NotOwner.selector);

        auction.withdrawPlatformFees();
    }

    function testCannotWithdrawPlatformFeesWhenBalanceIsZero() public {
        vm.prank(owner);

        vm.expectRevert(NothingToWithdraw.selector);

        auction.withdrawPlatformFees();
    }

    function testPlatformFeeIsTwoPercent() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 10 ether}(auctionId);

        AuctionData memory data = auction.getAuction(auctionId);

        vm.warp(data.endTime + 1);

        auction.finalizeAuction(auctionId);

        vm.prank(owner);

        assertEq(
            auction.getPlatformBalance(),
            0.2 ether
        );

        vm.prank(organizer);

        assertEq(
            auction.getSellerBalance(auctionId),
            9.8 ether
        );
    }

    // =============================================================
    //                         GETTERS
    // =============================================================

    function testGetAuctionCount() public {
        assertEq(auction.getAuctionCount(), 0);

        _createAuction();

        assertEq(auction.getAuctionCount(), 1);

        _createAuction();

        assertEq(auction.getAuctionCount(), 2);
    }

    function testGetAuctionUnknownId() public {
        vm.expectRevert(AuctionNotFound.selector);

        auction.getAuction(999);
    }

    function testGetRefundable() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        vm.prank(bidder2);
        auction.placeBid{value: 1.1 ether}(auctionId);

        assertEq(
            auction.getRefundable(auctionId, bidder1),
            1 ether
        );

        assertEq(
            auction.getRefundable(auctionId, bidder2),
            0
        );
    }

    function testGetMyRefundable() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);
        auction.placeBid{value: 1 ether}(auctionId);

        vm.prank(bidder2);
        auction.placeBid{value: 1.1 ether}(auctionId);

        vm.prank(bidder1);

        assertEq(
            auction.getMyRefundable(auctionId),
            1 ether
        );

        vm.prank(bidder2);

        assertEq(
            auction.getMyRefundable(auctionId),
            0
        );
    }

    function testOnlySellerCanGetSellerBalance() public {
        uint256 auctionId = _createAuction();

        vm.prank(bidder1);

        vm.expectRevert(NotSeller.selector);

        auction.getSellerBalance(auctionId);
    }

    function testGetSellerBalanceUnknownAuction() public {
        vm.prank(organizer);

        vm.expectRevert(AuctionNotFound.selector);

        auction.getSellerBalance(999);
    }

    function testOnlyOwnerCanGetPlatformBalance() public {
        vm.prank(stranger);

        vm.expectRevert(NotOwner.selector);

        auction.getPlatformBalance();
    }
}