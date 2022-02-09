// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFixedRental {
    event Lend(
        address indexed lenderAddress,
        uint256 indexed tokenID,
        uint256 lendingID,
        uint8 rentDuration,
        uint256 rentPrice
    );

    event Rent(
        address indexed renterAddress,
        uint256 indexed lendingID,
        uint256 indexed rentingID,
        uint8 rentDuration,
        uint32 rentedAt
    );

    event StopLend(uint256 indexed lendingID, uint32 stoppedAt);

    event RentClaimed(uint256 indexed rentingID, uint32 collectedAt);

    struct CallData {
        uint256 tokenID;
        uint256 lendingID;
        uint256 rentingID;
        uint8 rentDuration;
        uint256 rentPrice;
    }

    struct Lending {
        address payable lenderAddress;
        uint8 rentDuration;
        uint256 rentPrice;
        bool isLended;
    }

    struct Renting {
        address payable renterAddress;
        uint8 rentDuration;
        uint32 rentedAt;
    }

    // creates the lending structs and adds them to the enumerable set
    function lend(
        uint256 tokenID,
        uint8 rentDuration,
        uint256 rentPrice
    ) external;

    function stopLend(
        uint256 tokenID,
        uint256 lendingID
    ) external;

    // creates the renting structs and adds them to the enumerable set
    function rent(
        uint256 tokenID,
        uint256 lendingID,
        uint8 rentDuration
    ) external payable;

    function claimRent(
        uint256 tokenID,
        uint256 lendingID,
        uint256 rentingID
    ) external;
}
