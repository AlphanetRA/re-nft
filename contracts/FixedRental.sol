// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./interfaces/IFixedRental.sol";

contract FixedRental is IFixedRental, ERC721Holder {

    address private nftAddress;
    address private admin;
    address payable private beneficiary;
    uint256 private lendingID = 1;
    uint256 private rentingID = 1;
    bool public paused = false;
    uint256 public rentFee = 0;
    uint256 private constant SECONDS_IN_DAY = 86400;
    mapping(bytes32 => Lending) private lendings;
    mapping(bytes32 => Renting) private rentings;

    modifier onlyAdmin() {
        require(msg.sender == admin, "FixedRental::not admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "FixedRental::paused");
        _;
    }

    constructor(
        address _nftAddress,
        address payable _beneficiary,
        address _admin,
        uint256 _rentFee
    ) {
        ensureIsNotZeroAddr(_nftAddress);
        ensureIsNotZeroAddr(_beneficiary);
        ensureIsNotZeroAddr(_admin);
        nftAddress = _nftAddress;
        beneficiary = _beneficiary;
        admin = _admin;
        rentFee = _rentFee;
    }

    /**
    * @notice list token to marketplace
    * @param tokenID token ID
    * @param rentDuration rent duration
    * @param rentPrice rent price
    * @dev
    */
    function lend(
        uint256 tokenID,
        uint8 rentDuration,
        uint256 rentPrice
    ) external override notPaused {
        handleLend(
            createLendCallData(
                tokenID,
                rentDuration,
                rentPrice
            )
        );
    }

    /**
    * @notice down token from marketplace
    * @param tokenID token ID
    * @param _lendingID lending ID
    * @dev
    */
    function stopLend(
        uint256 tokenID,
        uint256 _lendingID
    ) external override notPaused {
        handleStopLend(
            createActionCallData(
                tokenID,
                _lendingID,
                0
            )
        );
    }

    /**
    * @notice rent token already lent from marketplace
    * @param tokenID token ID
    * @param _lendingID lending ID
    * @param rentDuration rent duration
    * @dev
    */
    function rent(
        uint256 tokenID,
        uint256 _lendingID,
        uint8 rentDuration
    ) external payable override notPaused {
        handleRent(
            createRentCallData(
                tokenID,
                _lendingID,
                rentDuration
            )
        );
    }

    /**
    * @notice return back token after rent duration
    * @param tokenID token ID
    * @param _lendingID lending ID
    * @param _rentingID renting ID
    * @dev
    */
    function claimRent(
        uint256 tokenID,
        uint256 _lendingID,
        uint256 _rentingID
    ) external override notPaused {
        handleClaimRent(
            createActionCallData(
                tokenID,
                _lendingID,
                _rentingID
            )
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function handleLend(IFixedRental.CallData memory cd) private {
        ensureIsLendable(cd);
        bytes32 identifier = keccak256(
            abi.encodePacked(
                cd.tokenID,
                lendingID
            )
        );
        IFixedRental.Lending storage lending = lendings[identifier];

        ensureIsNull(lending);

        lendings[identifier] = IFixedRental.Lending({
            lenderAddress: payable(msg.sender),
            rentDuration: cd.rentDuration,
            rentPrice: cd.rentPrice,
            isLended: false
        });
        emit IFixedRental.Lend(
            msg.sender,
            cd.tokenID,
            lendingID,
            cd.rentDuration,
            cd.rentPrice
        );
        lendingID++;

        IERC721(nftAddress).transferFrom(msg.sender, address(this), cd.tokenID);
    }

    function handleStopLend(IFixedRental.CallData memory cd) private {
        bytes32 lendingIdentifier = keccak256(
            abi.encodePacked(
                cd.tokenID,
                cd.lendingID
            )
        );
        Lending storage lending = lendings[lendingIdentifier];

        ensureIsNotNull(lending);
        ensureIsStoppable(lending, msg.sender);

        emit IFixedRental.StopLend(cd.lendingID, uint32(block.timestamp));
        delete lendings[lendingIdentifier];

        IERC721(nftAddress).transferFrom(address(this), msg.sender, cd.tokenID);
    }

    function handleRent(IFixedRental.CallData memory cd) private {
        bytes32 lendingIdentifier = keccak256(
            abi.encodePacked(
                cd.tokenID,
                cd.lendingID
            )
        );
        bytes32 rentingIdentifier = keccak256(
            abi.encodePacked(
                cd.tokenID,
                rentingID
            )
        );
        IFixedRental.Lending storage lending = lendings[lendingIdentifier];
        IFixedRental.Renting storage renting = rentings[rentingIdentifier];

        ensureIsNotNull(lending);
        ensureIsNull(renting);
        ensureIsRentable(lending, cd, msg.value, msg.sender);

        rentings[rentingIdentifier] = IFixedRental.Renting({
            renterAddress: payable(msg.sender),
            rentDuration: cd.rentDuration,
            rentedAt: uint32(block.timestamp)
        });
        lendings[lendingIdentifier].isLended = true;
        emit IFixedRental.Rent(
            msg.sender,
            cd.lendingID,
            rentingID,
            cd.rentDuration,
            renting.rentedAt
        );
        rentingID++;
    }

    function handleClaimRent(CallData memory cd) private {
        bytes32 lendingIdentifier = keccak256(
            abi.encodePacked(
                cd.tokenID,
                cd.lendingID
            )
        );
        bytes32 rentingIdentifier = keccak256(
            abi.encodePacked(
                cd.tokenID,
                cd.rentingID
            )
        );
        IFixedRental.Lending storage lending = lendings[lendingIdentifier];
        IFixedRental.Renting storage renting = rentings[rentingIdentifier];

        ensureIsNotNull(lending);
        ensureIsNotNull(renting);
        ensureIsClaimable(renting, block.timestamp);
        distributeClaimPayment(lending);

        lending.isLended = false;
        emit IFixedRental.RentClaimed(
            cd.rentingID,
            uint32(block.timestamp)
        );
        delete rentings[rentingIdentifier];
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function takeFee(uint256 fee) private {
        require(address(this).balance > fee, "FixedRental::not enough balance for rent fee");
        beneficiary.transfer(fee);
    }

    /**
    * @notice distribute payment to lender and beneficiary
    * @param lending lending
    * @dev
    */
    function distributeClaimPayment(
        IFixedRental.Lending memory lending
    ) private {
        if (rentFee != 0) takeFee(rentFee);
        lending.lenderAddress.transfer(lending.rentPrice - rentFee);
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    /**
    * @notice get lending info
    * @param tokenID token ID
    * @param _lendingID lending ID
    * @dev
    */
    function getLending(
        uint256 tokenID,
        uint256 _lendingID
    )
        external
        view
        returns (
            address,
            uint8,
            uint256
        )
    {
        bytes32 identifier = keccak256(
            abi.encodePacked(tokenID, _lendingID)
        );
        IFixedRental.Lending storage lending = lendings[identifier];
        return (
            lending.lenderAddress,
            lending.rentDuration,
            lending.rentPrice
        );
    }

    /**
    * @notice get renting info
    * @param tokenID token ID
    * @param _rentingID renting ID
    * @dev
    */
    function getRenting(
        uint256 tokenID,
        uint256 _rentingID
    )
        external
        view
        returns (
            address,
            uint8,
            uint32
        )
    {
        bytes32 identifier = keccak256(
            abi.encodePacked(tokenID, _rentingID)
        );
        IFixedRental.Renting storage renting = rentings[identifier];
        return (
            renting.renterAddress,
            renting.rentDuration,
            renting.rentedAt
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function createLendCallData(
        uint256 tokenID,
        uint8 rentDuration,
        uint256 rentPrice
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            tokenID: tokenID,
            lendingID: 0,
            rentingID: 0,
            rentDuration: rentDuration,
            rentPrice: rentPrice
        });
    }

    function createRentCallData(
        uint256 tokenID,
        uint256 _lendingID,
        uint8 rentDuration
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            tokenID: tokenID,
            lendingID: _lendingID,
            rentingID: 0,
            rentDuration: rentDuration,
            rentPrice: 0
        });
    }

    function createActionCallData(
        uint256 tokenID,
        uint256 _lendingID,
        uint256 _rentingID
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            tokenID: tokenID,
            lendingID: _lendingID,
            rentingID: _rentingID,
            rentDuration: 0,
            rentPrice: 0
        });
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function ensureIsNotZeroAddr(address addr) private pure {
        require(addr != address(0), "FixedRental::zero address");
    }

    function ensureIsZeroAddr(address addr) private pure {
        require(addr == address(0), "FixedRental::not a zero address");
    }

    function ensureIsNull(Lending memory lending) private pure {
        ensureIsZeroAddr(lending.lenderAddress);
        require(lending.rentDuration == 0, "FixedRental::duration not zero");
        require(lending.rentPrice == 0, "FixedRental::rent price not zero");
    }

    function ensureIsNotNull(Lending memory lending) private pure {
        ensureIsNotZeroAddr(lending.lenderAddress);
        require(lending.rentDuration != 0, "FixedRental::duration zero");
        require(lending.rentPrice != 0, "FixedRental::rent price is zero");
    }

    function ensureIsNull(Renting memory renting) private pure {
        ensureIsZeroAddr(renting.renterAddress);
        require(renting.rentDuration == 0, "FixedRental::duration not zero");
        require(renting.rentedAt == 0, "FixedRental::rented at not zero");
    }

    function ensureIsNotNull(Renting memory renting) private pure {
        ensureIsNotZeroAddr(renting.renterAddress);
        require(renting.rentDuration != 0, "FixedRental::duration is zero");
        require(renting.rentedAt != 0, "FixedRental::rented at is zero");
    }

    function ensureIsLendable(CallData memory cd) private pure {
        require(cd.rentDuration > 0, "FixedRental::duration is zero");
        require(cd.rentDuration <= type(uint8).max, "FixedRental::not uint8");
        require(uint32(cd.rentPrice) > 0, "FixedRental::rent price is zero");
    }

    function ensureIsRentable(
        Lending memory lending,
        CallData memory cd,
        uint256 value,
        address msgSender
    ) private pure {
        require(msgSender != lending.lenderAddress, "FixedRental::cant rent own nft");
        require(cd.rentDuration <= type(uint8).max, "FixedRental::not uint8");
        require(cd.rentDuration > 0, "FixedRental::duration is zero");
        require(value >= lending.rentPrice, "FixedRental::not enough rent price");
        require(!lending.isLended, "FixedRental::renting");
    }

    function ensureIsStoppable(Lending memory lending, address msgSender)
        private
        pure
    {
        require(lending.lenderAddress == msgSender, "FixedRental::not lender");
        require(!lending.isLended, "FixedRental::renting");
    }

    function ensureIsClaimable(
        IFixedRental.Renting memory renting,
        uint256 blockTimestamp
    ) private pure {
        require(
            isPastReturnDate(renting, blockTimestamp),
            "FixedRental::return date not passed"
        );
    }

    function isPastReturnDate(Renting memory renting, uint256 nowTime)
        private
        pure
        returns (bool)
    {
        require(nowTime > renting.rentedAt, "FixedRental::now before rented");
        return
            nowTime - renting.rentedAt > renting.rentDuration * SECONDS_IN_DAY;
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function setRentFee(uint256 newRentFee) external onlyAdmin {
        rentFee = newRentFee;
    }

    function setBeneficiary(address payable newBeneficiary) external onlyAdmin {
        beneficiary = newBeneficiary;
    }

    function setPaused(bool newPaused) external onlyAdmin {
        paused = newPaused;
    }
}