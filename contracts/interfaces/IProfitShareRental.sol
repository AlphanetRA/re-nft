// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProfitShareRental {
    event Lend(
        address indexed lenderAddress,
        uint256 indexed tokenID,
        uint256 lendingID,
        uint8 profitPercentageToRenter
    );

    event Rent(
        address indexed renterAddress,
        uint256 indexed lendingID,
        uint256 indexed rentingID,
        uint32 rentedAt
    );

    event StopLend(uint256 indexed lendingID, uint32 stoppedAt);

    event RentClaimed(uint256 indexed rentingID, uint32 collectedAt);

    event ProfitDistributed(
        uint256 indexed lendingID,
        address indexed lenderAddress,
        uint256 amountToLender,
        address indexed renterAddress,
        uint256 amountToRenter
    );

    struct CallData {
        uint256 tokenID;
        uint256 lendingID;
        uint256 rentingID;
        uint8 profitPercentageToRenter;
        uint256 totalShareAmount;
    }

    struct Lending {
        address payable lenderAddress;
        uint8 profitPercentageToRenter;
        bool isLended;
    }

    struct Renting {
        address payable renterAddress;
        uint32 rentedAt;
    }

    // creates the lending structs and adds them to the enumerable set
    function lend(
        uint256 tokenID,
        uint8 profitPercentageToRenter
    ) external;

    function stopLend(
        uint256 tokenID,
        uint256 lendingID
    ) external;

    // creates the renting structs and adds them to the enumerable set
    function rent(
        uint256 tokenID,
        uint256 lendingID
    ) external payable;

    function claimRent(
        uint256 tokenID,
        uint256 lendingID,
        uint256 rentingID
    ) external;

    // distribute profit to lender and renter
    function distributeProfit(
        uint256 tokenID,
        uint256 lendingID,
        uint256 rentingID,
        uint256 _totalAmount
    ) external;
}
