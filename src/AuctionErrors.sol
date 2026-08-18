// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

error InvalidStartPrice();
error InvalidMinimumIncrement();
error InvalidEndTime();
error EmptyMetadataCID();

error NotOwner();
error NotOrganizer();
error ZeroAddress();

error AuctionNotFound();
error AuctionNotActive();
error AuctionEnded();
error BidTooLow();

error AuctionNotEnded();
error AuctionAlreadyFinished();

error NotSeller();
error NothingToWithdraw();
error TransferFailed();