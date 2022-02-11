// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IProfitShareRental.sol";

contract ProfitShareRental is IProfitShareRental, ERC721Holder {
    using SafeERC20 for ERC20;

    address private nftAddress;
    address private paymentTokenAddress;
    address private profitTokenAddress;
    address private admin;
    address payable private beneficiary;
    uint256 private lendingID = 1;
    uint256 private rentingID = 1;
    bool public paused = false;
    uint256 public rentFee = 0;
    mapping(bytes32 => Lending) private lendings;
    mapping(bytes32 => Renting) private rentings;

    modifier onlyAdmin() {
        require(msg.sender == admin, "ProfitShareRental::not admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "ProfitShareRental::paused");
        _;
    }

    constructor(
        address _nftAddress,
        address _paymentTokenAddress,
        address _profitTokenAddress,
        address payable _beneficiary,
        address _admin,
        uint256 _rentFee
    ) {
        ensureIsNotZeroAddr(_nftAddress);
        ensureIsNotZeroAddr(_paymentTokenAddress);
        ensureIsNotZeroAddr(_profitTokenAddress);
        ensureIsNotZeroAddr(_beneficiary);
        ensureIsNotZeroAddr(_admin);
        nftAddress = _nftAddress;
        paymentTokenAddress = _paymentTokenAddress;
        profitTokenAddress = _profitTokenAddress;
        beneficiary = _beneficiary;
        admin = _admin;
        rentFee = _rentFee;
    }

    /**
    * @notice list token to marketplace
    * @param tokenID token ID
    * @param profitPercentageToRenter profit precentage assigned to renter
    * @dev called by lender
    */
    function lend(
        uint256 tokenID,
        uint8 profitPercentageToRenter
    ) external override notPaused {
        handleLend(
            createLendCallData(
                tokenID,
                profitPercentageToRenter
            )
        );
    }

    /**
    * @notice down token from marketplace
    * @param tokenID token ID
    * @param _lendingID lending ID
    * @dev called by lender
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
    * @notice rent token from marketplace
    * @param tokenID token ID
    * @param _lendingID lending ID
    * @dev called by renter
    */
    function rent(
        uint256 tokenID,
        uint256 _lendingID
    ) external override notPaused {
        handleRent(
            createRentCallData(
                tokenID,
                _lendingID
            )
        );
    }

    /**
    * @notice return back token
    * @param tokenID token ID
    * @param _lendingID lending ID
    * @param _rentingID renting ID
    * @dev called by lender or renter
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

    /**
    * @notice distribute profit to lender and renter
    * @param tokenID token ID
    * @param _lendingID lending ID
    * @param _rentingID renting ID
    * @param _totalAmount total amount to distribute
    * @dev called by renter
    */
    function distributeProfit(
        uint256 tokenID,
        uint256 _lendingID,
        uint256 _rentingID,
        uint256 _totalAmount
    ) external override notPaused {
        handleDistributeProfit(
            createDistributeCallData(
                tokenID,
                _lendingID,
                _rentingID,
                _totalAmount
            )
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function handleLend(IProfitShareRental.CallData memory cd) private {
        ensureIsLendable(cd);
        bytes32 identifier = keccak256(
            abi.encodePacked(
                cd.tokenID,
                lendingID
            )
        );
        IProfitShareRental.Lending storage lending = lendings[identifier];

        ensureIsNull(lending);

        lendings[identifier] = IProfitShareRental.Lending({
            lenderAddress: payable(msg.sender),
            profitPercentageToRenter: cd.profitPercentageToRenter,
            isLended: false
        });
        emit IProfitShareRental.Lend(
            msg.sender,
            cd.tokenID,
            lendingID,
            cd.profitPercentageToRenter
        );
        lendingID++;

        IERC721(nftAddress).transferFrom(msg.sender, address(this), cd.tokenID);
    }

    function handleStopLend(IProfitShareRental.CallData memory cd) private {
        bytes32 lendingIdentifier = keccak256(
            abi.encodePacked(
                cd.tokenID,
                cd.lendingID
            )
        );
        Lending storage lending = lendings[lendingIdentifier];

        ensureIsNotNull(lending);
        ensureIsStoppable(lending, msg.sender);

        emit IProfitShareRental.StopLend(cd.lendingID, uint32(block.timestamp));
        delete lendings[lendingIdentifier];

        IERC721(nftAddress).transferFrom(address(this), msg.sender, cd.tokenID);
    }

    function handleRent(IProfitShareRental.CallData memory cd) private {
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
        IProfitShareRental.Lending storage lending = lendings[lendingIdentifier];
        IProfitShareRental.Renting storage renting = rentings[rentingIdentifier];

        ensureIsNotNull(lending);
        ensureIsNull(renting);
        ensureIsRentable(lending, msg.sender);
        takeFee(msg.sender);

        rentings[rentingIdentifier] = IProfitShareRental.Renting({
            renterAddress: payable(msg.sender),
            rentedAt: uint32(block.timestamp)
        });
        lendings[lendingIdentifier].isLended = true;
        emit IProfitShareRental.Rent(
            msg.sender,
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
        IProfitShareRental.Lending storage lending = lendings[lendingIdentifier];
        IProfitShareRental.Renting storage renting = rentings[rentingIdentifier];

        ensureIsNotNull(lending);
        ensureIsNotNull(renting);
        ensureIsClaimable(renting, block.timestamp);

        lending.isLended = false;
        emit IProfitShareRental.RentClaimed(
            cd.rentingID,
            uint32(block.timestamp)
        );
        delete rentings[rentingIdentifier];
    }

    function handleDistributeProfit(CallData memory cd) private {
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
        IProfitShareRental.Lending storage lending = lendings[lendingIdentifier];
        IProfitShareRental.Renting storage renting = rentings[rentingIdentifier];

        ensureIsNotNull(lending);
        ensureIsNotNull(renting);

        require(renting.renterAddress == msg.sender, "ProfitShareRental::not renter");
        
        ERC20 profitToken = ERC20(profitTokenAddress);
        require(profitToken.balanceOf(address(this)) >= cd.totalShareAmount, "ProfitShareRental::not enough profit");
        uint256 amountToRenter = lending.profitPercentageToRenter / 100 * cd.totalShareAmount;
        uint256 amountToLender = cd.totalShareAmount - amountToRenter;
        profitToken.safeTransfer(lending.lenderAddress, amountToLender);
        profitToken.safeTransfer(renting.renterAddress, amountToRenter);

        emit IProfitShareRental.ProfitDistributed(
            cd.lendingID,
            lending.lenderAddress,
            amountToLender,
            renting.renterAddress,
            amountToRenter
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function takeFee(address renter) private {
        if (rentFee != 0) {
            ERC20 paymentToken = ERC20(paymentTokenAddress);
            require(paymentToken.balanceOf(renter) >= rentFee, "ProfitShareRental::not enough balance for rent fee");
            paymentToken.safeTransferFrom(renter, beneficiary, rentFee);
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
            uint8,
            bool
        )
    {
        bytes32 identifier = keccak256(
            abi.encodePacked(tokenID, _lendingID)
        );
        IProfitShareRental.Lending storage lending = lendings[identifier];
        return (
            lending.lenderAddress,
            lending.profitPercentageToRenter,
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
        IProfitShareRental.Renting storage renting = rentings[identifier];
        return (
            renting.renterAddress,
            renting.rentedAt
        );
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function createLendCallData(
        uint256 tokenID,
        uint8 profitPercentageToRenter
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            tokenID: tokenID,
            lendingID: 0,
            rentingID: 0,
            profitPercentageToRenter: profitPercentageToRenter,
            totalShareAmount: 0
        });
    }

    function createRentCallData(
        uint256 tokenID,
        uint256 _lendingID
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            tokenID: tokenID,
            lendingID: _lendingID,
            rentingID: 0,
            profitPercentageToRenter: 0,
            totalShareAmount: 0
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
            profitPercentageToRenter: 0,
            totalShareAmount: 0
        });
    }

    function createDistributeCallData(
        uint256 tokenID,
        uint256 _lendingID,
        uint256 _rentingID,
        uint256 _totalAmount
    ) private pure returns (CallData memory cd) {
        cd = CallData({
            tokenID: tokenID,
            lendingID: _lendingID,
            rentingID: _rentingID,
            profitPercentageToRenter: 0,
            totalShareAmount: _totalAmount
        });
    }

    //      .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.     .-.
    // `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'   `._.'

    function ensureIsNotZeroAddr(address addr) private pure {
        require(addr != address(0), "ProfitShareRental::zero address");
    }

    function ensureIsZeroAddr(address addr) private pure {
        require(addr == address(0), "ProfitShareRental::not a zero address");
    }

    function ensureIsNull(Lending memory lending) private pure {
        ensureIsZeroAddr(lending.lenderAddress);
        require(lending.profitPercentageToRenter == 0, "ProfitShareRental::profitPercentageToRenter not zero");
        require(!lending.isLended, "ProfitShareRental::already lended");
    }

    function ensureIsNotNull(Lending memory lending) private pure {
        ensureIsNotZeroAddr(lending.lenderAddress);
        require(lending.profitPercentageToRenter != 0, "ProfitShareRental::profitPercentageToRenter zero");
        require(lending.isLended, "ProfitShareRental::not lended");
    }

    function ensureIsNull(Renting memory renting) private pure {
        ensureIsZeroAddr(renting.renterAddress);
        require(renting.rentedAt == 0, "ProfitShareRental::rented at not zero");
    }

    function ensureIsNotNull(Renting memory renting) private pure {
        ensureIsNotZeroAddr(renting.renterAddress);
        require(renting.rentedAt != 0, "ProfitShareRental::rented at is zero");
    }

    function ensureIsLendable(CallData memory cd) private pure {
        require(cd.profitPercentageToRenter > 0, "ProfitShareRental::profitPercentageToRenter is zero");
        require(cd.profitPercentageToRenter <= 100, "ProfitShareRental::profitPercentageToRenter is greater than 100");
    }

    function ensureIsRentable(
        Lending memory lending,
        address msgSender
    ) private pure {
        require(msgSender != lending.lenderAddress, "ProfitShareRental::cant rent own nft");
        require(!lending.isLended, "ProfitShareRental::renting");
    }

    function ensureIsStoppable(Lending memory lending, address msgSender)
        private
        pure
    {
        require(lending.lenderAddress == msgSender, "ProfitShareRental::not lender");
        require(!lending.isLended, "ProfitShareRental::renting");
    }

    function ensureIsClaimable(
        IProfitShareRental.Renting memory renting,
        uint256 blockTimestamp
    ) private pure {
        require(
            isPastReturnDate(renting, blockTimestamp),
            "ProfitShareRental::return date not passed"
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
