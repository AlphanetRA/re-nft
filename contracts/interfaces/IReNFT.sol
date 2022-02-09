// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReNFT {
    event Lend(
        address indexed lenderAddress,
        uint256 indexed tokenID,
        uint256 lendingID,
        uint8 maxRentDuration,
        bytes4 dailyRentPrice
    );

    event Rent(
        address indexed renterAddress,
        uint256 indexed lendingID,
        uint256 indexed rentingID,
        uint8 rentDuration,
        uint32 rentedAt
    );

    event StopLend(uint256 indexed lendingID, uint32 stoppedAt);

    event StopRent(uint256 indexed rentingID, uint32 stoppedAt);

    event RentClaimed(uint256 indexed rentingID, uint32 collectedAt);

    struct CallData {
        uint256 tokenID;
        uint256 lendAmount;
        uint8 maxRentDuration;
        bytes4 dailyRentPrice;
        uint256 lendingID;
        uint256 rentingID;
        uint8 rentDuration;
        uint256 rentAmount;
    }

    // 2, 162, 170, 202, 218, 234, 242
    struct Lending {
        address payable lenderAddress;
        uint8 maxRentDuration;
        bytes4 dailyRentPrice;
        uint16 lendAmount;
        uint16 availableAmount;
    }

    // 180, 212
    struct Renting {
        address payable renterAddress;
        uint8 rentDuration;
        uint32 rentedAt;
        uint16 rentAmount;
    }

    // creates the lending structs and adds them to the enumerable set
    function lend(
        uint256 memory tokenID,
        uint256 memory lendAmount,
        uint8 memory maxRentDuration,
        bytes4 memory dailyRentPrice
    ) external;

    function stopLend(
        uint256 memory tokenID,
        uint256 memory lendingID
    ) external;

    // // creates the renting structs and adds them to the enumerable set
    function rent(
        uint256 memory tokenID,
        uint256 memory lendingID,
        uint8 memory rentDuration,
        uint256 memory rentAmount
    ) external payable;

    function stopRent(
        uint256 memory tokenID,
        uint256 memory lendingID,
        uint256 memory rentingID
    ) external;

    function claimRent(
        uint256 memory tokenID,
        uint256 memory lendingID,
        uint256 memory rentingID
    ) external;
}
