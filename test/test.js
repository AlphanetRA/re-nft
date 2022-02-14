const { expect } = require("chai");
const { ethers } = require("hardhat");
const utils = require("./helpers/utils")
const time = require("./helpers/time")

describe("FixedRental", function () {
  let unicorn, paymentToken, fixedRental, rentFee = 100;

  beforeEach(async () => {
    [ , beneficiary, fixedRentalAdmin, Alice, Bob] = await ethers.getSigners();

    const Unicorn = await ethers.getContractFactory("Unicorn");
    unicorn = await Unicorn.deploy();
    await unicorn.connect(Alice).mint();
    await unicorn.connect(Bob).mint();

    const PaymentToken = await hre.ethers.getContractFactory("PaymentToken");
    paymentToken = await PaymentToken.deploy();
    await paymentToken.transfer(Alice.address, 10000);
    await paymentToken.transfer(Bob.address, 10000);

    const FixedRental = await ethers.getContractFactory("FixedRental");
    fixedRental = await FixedRental.deploy(
      unicorn.address,
      paymentToken.address,
      beneficiary.address,
      fixedRentalAdmin.address,
      rentFee
    );
	});

  it("Should be able to lend a unicorn", async function () {
    let tokenIdAlice = 0;
    let tokenIdBob = 1;
    let rentDuration = 2;
    let rentPrice = 400;
    let lendingIdAlice = 1;
    let lendingIdBob = 2;

    await unicorn.connect(Alice).approve(fixedRental.address, tokenIdAlice);
    expect(await fixedRental.connect(Alice).lend(tokenIdAlice, rentDuration, rentPrice))
          .to.emit(fixedRental, "Lend")
          .withArgs(Alice.address, tokenIdAlice, lendingIdAlice, rentDuration, rentPrice);

    await unicorn.connect(Bob).approve(fixedRental.address, tokenIdBob);
    expect(await fixedRental.connect(Bob).lend(tokenIdBob, rentDuration, rentPrice))
          .to.emit(fixedRental, "Lend")
          .withArgs(Bob.address, tokenIdBob, lendingIdBob, rentDuration, rentPrice);
  });

  it("Should be able to rent a unicorn", async function () {
    let tokenId = 0;
    let rentDuration = 2;
    let rentPrice = 400;
    let lendingId = 1;
    let rentingId = 1;

    await unicorn.connect(Alice).approve(fixedRental.address, tokenId);
    await fixedRental.connect(Alice).lend(tokenId, rentDuration, rentPrice);

    await paymentToken.connect(Bob).approve(fixedRental.address, rentPrice);
    let block = await ethers.provider.getBlock();
    expect(await fixedRental.connect(Bob).rent(tokenId, lendingId))
          .to.emit(fixedRental, "Rent")
          .withArgs(Bob.address, lendingId, rentingId, rentDuration, block.timestamp + 1);

    expect(await paymentToken.balanceOf(beneficiary.address)).to.equal(rentFee);
  });

  it("Should not be able to rent a unicorn by lender", async function () {
    let tokenId = 0;
    let rentDuration = 2;
    let rentPrice = 400;
    let lendingId = 1;
    let rentingId = 1;

    await unicorn.connect(Alice).approve(fixedRental.address, tokenId);
    await fixedRental.connect(Alice).lend(tokenId, rentDuration, rentPrice);

    await paymentToken.connect(Alice).approve(fixedRental.address, rentPrice);
    await utils.shouldThrow(fixedRental.connect(Alice).rent(tokenId, lendingId));
  });

  it("Should be able to stop a rent", async function () {
    let tokenId = 0;
    let rentDuration = 2;
    let rentPrice = 400;
    let lendingId = 1;
    let rentingId = 1;

    await unicorn.connect(Alice).approve(fixedRental.address, tokenId);
    await fixedRental.connect(Alice).lend(tokenId, rentDuration, rentPrice);

    await paymentToken.connect(Bob).approve(fixedRental.address, rentPrice);
    await fixedRental.connect(Bob).rent(tokenId, lendingId);

    expect(await paymentToken.balanceOf(beneficiary.address)).to.equal(rentFee);

    await time.increase(time.duration.days(rentDuration));

    let block = await ethers.provider.getBlock();
    expect(await fixedRental.connect(Bob).claimRent(tokenId, lendingId, rentingId))
          .to.emit(fixedRental, "RentClaimed")
          .withArgs(rentingId, block.timestamp + 1);
  });

  it("Should not be able to stop a rent by lender", async function () {
    let tokenId = 0;
    let rentDuration = 2;
    let rentPrice = 400;
    let lendingId = 1;
    let rentingId = 1;

    await unicorn.connect(Alice).approve(fixedRental.address, tokenId);
    await fixedRental.connect(Alice).lend(tokenId, rentDuration, rentPrice);

    await paymentToken.connect(Bob).approve(fixedRental.address, rentPrice);
    await fixedRental.connect(Bob).rent(tokenId, lendingId);

    expect(await paymentToken.balanceOf(beneficiary.address)).to.equal(rentFee);

    await time.increase(time.duration.days(rentDuration));

    await utils.shouldThrow(fixedRental.connect(Alice).claimRent(tokenId, lendingId, rentingId));
  });

  context("Should be able to stop free lend", async () => {
    it("After lending a unicorn, should be able to stop it again", async function () {
      let tokenId = 0;
      let rentDuration = 2;
      let rentPrice = 400;
      let lendingId = 1;
  
      await unicorn.connect(Alice).approve(fixedRental.address, tokenId);
      await fixedRental.connect(Alice).lend(tokenId, rentDuration, rentPrice);

      let block = await ethers.provider.getBlock();
      expect(await fixedRental.connect(Alice).stopLend(tokenId, lendingId))
            .to.emit(fixedRental, "StopLend")
            .withArgs(lendingId, block.timestamp + 1)
    });
    it("After lending a unicorn and renting it, should not be able to stop that lending", async function () {
      let tokenId = 0;
      let rentDuration = 2;
      let rentPrice = 400;
      let lendingId = 1;
  
      await unicorn.connect(Alice).approve(fixedRental.address, tokenId);
      await fixedRental.connect(Alice).lend(tokenId, rentDuration, rentPrice);

      await paymentToken.connect(Bob).approve(fixedRental.address, rentPrice);
      await fixedRental.connect(Bob).rent(tokenId, lendingId);

      expect(await paymentToken.balanceOf(beneficiary.address)).to.equal(rentFee);

      await utils.shouldThrow(fixedRental.connect(Alice).stopLend(tokenId, lendingId));
    });
    it("After lending a unicorn, renting it and stopping renting, should be able to stop that lending", async function () {
      let tokenId = 0;
      let rentDuration = 2;
      let rentPrice = 400;
      let lendingId = 1;
      let rentingId = 1;
  
      await unicorn.connect(Alice).approve(fixedRental.address, tokenId);
      await fixedRental.connect(Alice).lend(tokenId, rentDuration, rentPrice);

      await paymentToken.connect(Bob).approve(fixedRental.address, rentPrice);
      await fixedRental.connect(Bob).rent(tokenId, lendingId);

      expect(await paymentToken.balanceOf(beneficiary.address)).to.equal(rentFee);

      await time.increase(time.duration.days(rentDuration));

      await fixedRental.connect(Bob).claimRent(tokenId, lendingId, rentingId);
      
      let block = await ethers.provider.getBlock();
      expect(await fixedRental.connect(Alice).stopLend(tokenId, lendingId))
            .to.emit(fixedRental, "StopLend")
            .withArgs(lendingId, block.timestamp + 1)
    });
  });
});

describe("ProfitShareRental", function () {
  let unicorn, paymentToken, profitToken, profitShareRental, rentFee = 100;

  beforeEach(async () => {
    [ , profitTokenAdmin, beneficiary, profitShareRentalAdmin, Alice, Bob] = await ethers.getSigners();

    const Unicorn = await ethers.getContractFactory("Unicorn");
    unicorn = await Unicorn.deploy();
    await unicorn.connect(Alice).mint();
    await unicorn.connect(Bob).mint();

    const PaymentToken = await hre.ethers.getContractFactory("PaymentToken");
    paymentToken = await PaymentToken.deploy();
    await paymentToken.transfer(Alice.address, 10000);
    await paymentToken.transfer(Bob.address, 10000);

    const ProfitToken = await hre.ethers.getContractFactory("ProfitToken");
    profitToken = await ProfitToken.deploy(profitTokenAdmin.address);

    const ProfitShareRental = await ethers.getContractFactory("ProfitShareRental");
    profitShareRental = await ProfitShareRental.deploy(
      unicorn.address,
      paymentToken.address,
      profitToken.address,
      beneficiary.address,
      profitShareRentalAdmin.address,
      rentFee
    );
	});

  it("Should be able to lend a unicorn", async function () {
    let tokenIdAlice = 0;
    let tokenIdBob = 1;
    let profitPercentageToRenter = 10;
    let lendingIdAlice = 1;
    let lendingIdBob = 2;

    await unicorn.connect(Alice).approve(profitShareRental.address, tokenIdAlice);
    expect(await profitShareRental.connect(Alice).lend(tokenIdAlice, profitPercentageToRenter))
          .to.emit(profitShareRental, "Lend")
          .withArgs(Alice.address, tokenIdAlice, lendingIdAlice, profitPercentageToRenter);

    await unicorn.connect(Bob).approve(profitShareRental.address, tokenIdBob);
    expect(await profitShareRental.connect(Bob).lend(tokenIdBob, profitPercentageToRenter))
          .to.emit(profitShareRental, "Lend")
          .withArgs(Bob.address, tokenIdBob, lendingIdBob, profitPercentageToRenter);
  });

  it("Should be able to rent a unicorn", async function () {
    let tokenId = 0;
    let profitPercentageToRenter = 10;
    let lendingId = 1;
    let rentingId = 1;

    await unicorn.connect(Alice).approve(profitShareRental.address, tokenId);
    await profitShareRental.connect(Alice).lend(tokenId, profitPercentageToRenter);

    await paymentToken.connect(Bob).approve(profitShareRental.address, rentFee);
    let block = await ethers.provider.getBlock();
    expect(await profitShareRental.connect(Bob).rent(tokenId, lendingId))
          .to.emit(profitShareRental, "Rent")
          .withArgs(Bob.address, lendingId, rentingId, block.timestamp + 1);

    expect(await paymentToken.balanceOf(beneficiary.address)).to.equal(rentFee);
  });

  it("Should not be able to rent a unicorn by lender", async function () {
    let tokenId = 0;
    let profitPercentageToRenter = 10;
    let lendingId = 1;
    let rentingId = 1;

    await unicorn.connect(Alice).approve(profitShareRental.address, tokenId);
    await profitShareRental.connect(Alice).lend(tokenId, profitPercentageToRenter);

    await paymentToken.connect(Alice).approve(profitShareRental.address, rentFee);
    await utils.shouldThrow(profitShareRental.connect(Alice).rent(tokenId, lendingId));
  });

  it("Should be able to stop a rent by renter", async function () {
    let tokenId = 0;
    let profitPercentageToRenter = 10;
    let lendingId = 1;
    let rentingId = 1;

    await unicorn.connect(Alice).approve(profitShareRental.address, tokenId);
    await profitShareRental.connect(Alice).lend(tokenId, profitPercentageToRenter);

    await paymentToken.connect(Bob).approve(profitShareRental.address, rentFee);
    await profitShareRental.connect(Bob).rent(tokenId, lendingId);

    expect(await paymentToken.balanceOf(beneficiary.address)).to.equal(rentFee);

    let block = await ethers.provider.getBlock();
    expect(await profitShareRental.connect(Bob).claimRent(tokenId, lendingId, rentingId))
          .to.emit(profitShareRental, "RentClaimed")
          .withArgs(rentingId, block.timestamp + 1);
  });

  it("Should be able to stop a rent by lender", async function () {
    let tokenId = 0;
    let profitPercentageToRenter = 10;
    let lendingId = 1;
    let rentingId = 1;

    await unicorn.connect(Alice).approve(profitShareRental.address, tokenId);
    await profitShareRental.connect(Alice).lend(tokenId, profitPercentageToRenter);

    await paymentToken.connect(Bob).approve(profitShareRental.address, rentFee);
    await profitShareRental.connect(Bob).rent(tokenId, lendingId);

    expect(await paymentToken.balanceOf(beneficiary.address)).to.equal(rentFee);

    let block = await ethers.provider.getBlock();
    expect(await profitShareRental.connect(Alice).claimRent(tokenId, lendingId, rentingId))
          .to.emit(profitShareRental, "RentClaimed")
          .withArgs(rentingId, block.timestamp + 1);
  });

  context("Should be able to stop free lend", async () => {
    it("After lending a unicorn, should be able to stop it again", async function () {
      let tokenId = 0;
      let profitPercentageToRenter = 10;
      let lendingId = 1;
      let rentingId = 1;

      await unicorn.connect(Alice).approve(profitShareRental.address, tokenId);
      await profitShareRental.connect(Alice).lend(tokenId, profitPercentageToRenter);

      let block = await ethers.provider.getBlock();
      expect(await profitShareRental.connect(Alice).stopLend(tokenId, lendingId))
            .to.emit(profitShareRental, "StopLend")
            .withArgs(lendingId, block.timestamp + 1);
    });
    it("After lending a unicorn and renting it, should not be able to stop that lending", async function () {
      let tokenId = 0;
      let profitPercentageToRenter = 10;
      let lendingId = 1;
      let rentingId = 1;

      await unicorn.connect(Alice).approve(profitShareRental.address, tokenId);
      await profitShareRental.connect(Alice).lend(tokenId, profitPercentageToRenter);

      await paymentToken.connect(Bob).approve(profitShareRental.address, rentFee);
      await profitShareRental.connect(Bob).rent(tokenId, lendingId);

      expect(await paymentToken.balanceOf(beneficiary.address)).to.equal(rentFee);

      await utils.shouldThrow(profitShareRental.connect(Alice).stopLend(tokenId, lendingId));
    });
    it("After lending a unicorn, renting it and stopping renting, should be able to stop that lending", async function () {
      let tokenId = 0;
      let profitPercentageToRenter = 10;
      let lendingId = 1;
      let rentingId = 1;

      await unicorn.connect(Alice).approve(profitShareRental.address, tokenId);
      await profitShareRental.connect(Alice).lend(tokenId, profitPercentageToRenter);

      await paymentToken.connect(Bob).approve(profitShareRental.address, rentFee);
      await profitShareRental.connect(Bob).rent(tokenId, lendingId);

      expect(await paymentToken.balanceOf(beneficiary.address)).to.equal(rentFee);

      await profitShareRental.connect(Bob).claimRent(tokenId, lendingId, rentingId);
      
      let block = await ethers.provider.getBlock();
      expect(await profitShareRental.connect(Alice).stopLend(tokenId, lendingId))
            .to.emit(profitShareRental, "StopLend")
            .withArgs(lendingId, block.timestamp + 1)
    });
  });

  it("Should be able to share the profit", async function () {
    let tokenId = 0;
    let profitPercentageToRenter = 10;
    let lendingId = 1;
    let rentingId = 1;
    let shareAmount = 1000;
    let amountToBob = profitPercentageToRenter * shareAmount / 100;
    let amountToAlice = shareAmount - amountToBob;

    await unicorn.connect(Alice).approve(profitShareRental.address, tokenId);
    await profitShareRental.connect(Alice).lend(tokenId, profitPercentageToRenter);

    await paymentToken.connect(Bob).approve(profitShareRental.address, rentFee);
    await profitShareRental.connect(Bob).rent(tokenId, lendingId);

    expect(await paymentToken.balanceOf(beneficiary.address)).to.equal(rentFee);

    await profitToken.connect(profitTokenAdmin).mint(profitShareRental.address, shareAmount);
    
    await profitShareRental.connect(Bob).distributeProfit(tokenId, lendingId, rentingId, shareAmount);

    expect(await profitToken.balanceOf(Alice.address)).to.equal(amountToAlice);
    expect(await profitToken.balanceOf(Bob.address)).to.equal(amountToBob);
  });
});

describe("DirectRental", function () {
  let unicorn, paymentToken, directRental, rentFee = 100;

  beforeEach(async () => {
    [ , beneficiary, directRentalAdmin, Alice, Bob] = await ethers.getSigners();

    const Unicorn = await ethers.getContractFactory("Unicorn");
    unicorn = await Unicorn.deploy();
    await unicorn.connect(Alice).mint();
    await unicorn.connect(Bob).mint();

    const PaymentToken = await hre.ethers.getContractFactory("PaymentToken");
    paymentToken = await PaymentToken.deploy();
    await paymentToken.transfer(Alice.address, 10000);
    await paymentToken.transfer(Bob.address, 10000);

    const DirectRental = await ethers.getContractFactory("DirectRental");
    directRental = await DirectRental.deploy(
      unicorn.address,
      paymentToken.address,
      beneficiary.address,
      directRentalAdmin.address,
      rentFee
    );
	});

  it("Should be able to rent a unicorn", async function () {
    let tokenId = 0;
    let lendingId = 1;
    let rentingId = 1;

    await unicorn.connect(Alice).approve(directRental.address, tokenId);
    await paymentToken.connect(Alice).approve(directRental.address, rentFee);

    let block = await ethers.provider.getBlock();
    expect(await directRental.connect(Alice).rent(tokenId, Bob.address))
          .to.emit(directRental, "Lend")
          .withArgs(Alice.address, tokenId, lendingId)
          .to.emit(directRental, "Rent")
          .withArgs(Bob.address, lendingId, rentingId, block.timestamp + 1);
  });

  it("Should be able to stop the renting", async function () {
    let tokenId = 0;
    let lendingId = 1;
    let rentingId = 1;

    await unicorn.connect(Alice).approve(directRental.address, tokenId);
    await paymentToken.connect(Alice).approve(directRental.address, rentFee);
    await directRental.connect(Alice).rent(tokenId, Bob.address);

    let block = await ethers.provider.getBlock();
    expect(await directRental.connect(Alice).claimRent(tokenId, lendingId, rentingId))
          .to.emit(directRental, "RentClaimed")
          .withArgs(rentingId, block.timestamp + 1)
          .to.emit(directRental, "StopLend")
          .withArgs(lendingId, block.timestamp + 1);
  });
});
