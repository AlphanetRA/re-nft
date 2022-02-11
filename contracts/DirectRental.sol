// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IDirectRental.sol";

contract DirectRental is IDirectRental, ERC721Holder {
    using SafeERC20 for ERC20;

    address private nftAddress;
    address private paymentTokenAddress;
    address private admin;
    address payable private beneficiary;
    uint256 private lendingID = 1;
    uint256 private rentingID = 1;
    bool public paused = false;
    uint256 public rentFee = 0;
    mapping(bytes32 => Lending) private lendings;
    mapping(bytes32 => Renting) private rentings;

    modifier onlyAdmin() {
        require(msg.sender == admin, "DirectRental::not admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "DirectRental::paused");
        _;
    }

    constructor(
        address _nftAddress,
        address _paymentTokenAddress,
        address payable _beneficiary,
        address _admin,
        uint256 _rentFee
    ) {
        ensureIsNotZeroAddr(_nftAddress);
        ensureIsNotZeroAddr(_paymentTokenAddress);
        ensureIsNotZeroAddr(_beneficiary);
        ensureIsNotZeroAddr(_admin);
        nftAddress = _nftAddress;
        paymentTokenAddress = _paymentTokenAddress;
        beneficiary = _beneficiary;
        admin = _admin;
        rentFee = _rentFee;
    }

    /**
    * @notice rent token
    * @param tokenID token ID
    * @param _renterAddress renter address
    * @dev called by lender
    */
    function rent(
        uint256 tokenID,
        address _renterAddress
    ) external override notPaused {
        uint256 _lendingID = handleLend(
            createLendCallData(tokenID)
        );
        handleRent(
            createRentCallData(
                tokenID,
                _lendingID,
                _renterAddress
            )
        );
    }

    /**
    * @notice return back token
    * @param tokenID token ID
    * @param _lendingID lending ID
    * @param _rentingID renting ID
    * @dev called by lender
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
        handleStopLend(
            createActionCallData(
                tokenID,
                _lendingID,
                0
            )
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function handleLend(IDirectRental.CallData memory cd) private returns (uint256) {
        bytes32 identifier = keccak256(
            abi.encodePacked(
                cd.tokenID,
                lendingID
            )
        );
        IDirectRental.Lending storage lending = lendings[identifier];

        ensureIsNull(lending);

        lendings[identifier] = IDirectRental.Lending({
            lenderAddress: payable(msg.sender),
            isLended: false
        });
        emit IDirectRental.Lend(
            msg.sender,
            cd.tokenID,
            lendingID
        );
        lendingID++;

        IERC721(nftAddress).transferFrom(msg.sender, address(this), cd.tokenID);
        return lendingID - 1;
    }

    function handleStopLend(IDirectRental.CallData memory cd) private {
        bytes32 lendingIdentifier = keccak256(
            abi.encodePacked(
                cd.tokenID,
                cd.lendingID
            )
        );
        Lending storage lending = lendings[lendingIdentifier];

        ensureIsNotNull(lending);
        ensureIsStoppable(lending, msg.sender);

        emit IDirectRental.StopLend(cd.lendingID, uint32(block.timestamp));
        delete lendings[lendingIdentifier];

        IERC721(nftAddress).transferFrom(address(this), msg.sender, cd.tokenID);
    }

    function handleRent(IDirectRental.CallData memory cd) private {
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
        IDirectRental.Lending storage lending = lendings[lendingIdentifier];
        IDirectRental.Renting storage renting = rentings[rentingIdentifier];

        ensureIsNotNull(lending);
        ensureIsNull(renting);
        ensureIsRentable(lending, msg.sender);
        takeFee(msg.sender);

        rentings[rentingIdentifier] = IDirectRental.Renting({
            renterAddress: payable(cd.renterAddress),
            rentedAt: uint32(block.timestamp)
        });
        lendings[lendingIdentifier].isLended = true;
        emit IDirectRental.Rent(
            cd.renterAddress,
            cd.lendingID,
            rentingID,
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
        IDirectRental.Lending storage lending = lendings[lendingIdentifier];
        IDirectRental.Renting storage renting = rentings[rentingIdentifier];

        ensureIsNotNull(lending);
        ensureIsNotNull(renting);
        ensureIsClaimable(renting, block.timestamp);

        lending.isLended = false;
        emit IDirectRental.RentClaimed(
            cd.rentingID,
            uint32(block.timestamp)
        );
        delete rentings[rentingIdentifier];
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function takeFee(address lender) private {
        if (rentFee != 0) {
            ERC20 paymentToken = ERC20(paymentTokenAddress);
            require(paymentToken.balanceOf(lender) >= rentFee, "DirectRental::not enough balance for rent fee");
            paymentToken.safeTransferFrom(lender, beneficiary, rentFee);
        }
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
            bool
        )
    {
        bytes32 identifier = keccak256(
            abi.encodePacked(tokenID, _lendingID)
        );
        IDirectRental.Lending storage lending = lendings[identifier];
        return (
            lending.lenderAddress,
            lending.isLended
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
            uint32
        )
    {
        bytes32 identifier = keccak256(
            abi.encodePacked(tokenID, _rentingID)
        );
        IDirectRental.Renting storage renting = rentings[identifier];
        return (
            renting.renterAddress,
            renting.rentedAt
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function createLendCallData(uint256 tokenID) private pure returns (CallData memory cd) {
        cd = CallData({
            tokenID: tokenID,
            lendingID: 0,
            rentingID: 0,
            renterAddress: address(0)
        });
    }

    function createRentCallData(
        uint256 tokenID,
        uint256 _lendingID,
        address renterAddress
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            tokenID: tokenID,
            lendingID: _lendingID,
            rentingID: 0,
            renterAddress: renterAddress
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
            renterAddress: address(0)
        });
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function ensureIsNotZeroAddr(address addr) private pure {
        require(addr != address(0), "DirectRental::zero address");
    }

    function ensureIsZeroAddr(address addr) private pure {
        require(addr == address(0), "DirectRental::not a zero address");
    }

    function ensureIsNull(Lending memory lending) private pure {
        ensureIsZeroAddr(lending.lenderAddress);
        require(!lending.isLended, "DirectRental::already lended");
    }

    function ensureIsNotNull(Lending memory lending) private pure {
        ensureIsNotZeroAddr(lending.lenderAddress);
        require(lending.isLended, "DirectRental::not lended");
    }

    function ensureIsNull(Renting memory renting) private pure {
        ensureIsZeroAddr(renting.renterAddress);
        require(renting.rentedAt == 0, "DirectRental::rented at not zero");
    }

    function ensureIsNotNull(Renting memory renting) private pure {
        ensureIsNotZeroAddr(renting.renterAddress);
        require(renting.rentedAt != 0, "DirectRental::rented at is zero");
    }

    function ensureIsRentable(
        Lending memory lending,
        address msgSender
    ) private pure {
        require(msgSender == lending.lenderAddress, "DirectRental::cant rent own nft");
        require(!lending.isLended, "DirectRental::renting");
    }

    function ensureIsStoppable(Lending memory lending, address msgSender)
        private
        pure
    {
        require(lending.lenderAddress == msgSender, "DirectRental::not lender");
        require(!lending.isLended, "DirectRental::renting");
    }

    function ensureIsClaimable(
        IDirectRental.Renting memory renting,
        uint256 blockTimestamp
    ) private pure {
        require(
            isPastReturnDate(renting, blockTimestamp),
            "DirectRental::return date not passed"
        );
    }

    function isPastReturnDate(Renting memory renting, uint256 nowTime)
        private
        pure
        returns (bool)
    {
        return nowTime > renting.rentedAt;
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

    function setPaymentTokenAddress(address newPaymentTokenAddress) external onlyAdmin {
        paymentTokenAddress = newPaymentTokenAddress;
    }
}
