// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDirectRental {
    event Lend(
        address indexed lenderAddress,
        uint256 indexed tokenID,
        uint256 lendingID
    );

    event Rent(
        address indexed renterAddress,
        uint256 indexed lendingID,
        uint256 indexed rentingID,
        uint32 rentedAt
    );

    event StopLend(uint256 indexed lendingID, uint32 stoppedAt);

    event RentClaimed(uint256 indexed rentingID, uint32 collectedAt);

    struct CallData {
        uint256 tokenID;
        uint256 lendingID;
        uint256 rentingID;
        address renterAddress;
    }

    struct Lending {
        address payable lenderAddress;
        bool isLended;
    }

    struct Renting {
        address payable renterAddress;
        uint32 rentedAt;
    }

    function rent(
        uint256 tokenID,
        address renterAddress
    ) external;

    function claimRent(
        uint256 tokenID,
        uint256 lendingID,
        uint256 rentingID
    ) external;
}
