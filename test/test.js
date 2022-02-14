const { expect } = require("chai");
const { ethers } = require("hardhat");
const utils = require("./helpers/utils")
const time = require("./helpers/time")

describe("FixedRental", function () {
  let unicorn, paymentToken, profitToken, fixedRental;

  beforeEach(async () => {
    [ , profitTokenAdmin, beneficiary, fixedRentalAdmin, Alice, Bob] = await ethers.getSigners();

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

    const FixedRental = await ethers.getContractFactory("FixedRental");
    fixedRental = await FixedRental.deploy(
      unicorn.address,
      paymentToken.address,
      beneficiary.address,
      fixedRentalAdmin.address,
      100
    );
	})

  it("Should be able to lend a unicorn", async function () {
    let tokenIdAlice = 0;
    let tokenIdBob = 1;
    let rentDuration = 2;
    let rentPrice = 400;
    let lendingIdAlice = 1;
    let lendingIdBob = 2;

    await unicorn.connect(Alice).approve(fixedRental.address, tokenIdAlice);
    await expect(fixedRental.connect(Alice).lend(tokenIdAlice, rentDuration, rentPrice))
          .to.emit(fixedRental, "Lend")
          .withArgs(Alice.address, tokenIdAlice, lendingIdAlice, rentDuration, rentPrice);

    await unicorn.connect(Bob).approve(fixedRental.address, tokenIdBob);
    await expect(fixedRental.connect(Bob).lend(tokenIdBob, rentDuration, rentPrice))
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
    await expect(fixedRental.connect(Bob).rent(tokenId, lendingId))
          .to.emit(fixedRental, "Rent")
          .withArgs(Bob.address, lendingId, rentingId, rentDuration, block.timestamp + 1);
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

    await time.increase(time.duration.days(rentDuration));

    let block = await ethers.provider.getBlock();
    await expect(fixedRental.connect(Bob).claimRent(tokenId, lendingId, rentingId))
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
      await expect(fixedRental.connect(Alice).stopLend(tokenId, lendingId))
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

      await time.increase(time.duration.days(rentDuration));

      await fixedRental.connect(Bob).claimRent(tokenId, lendingId, rentingId);
      
      let block = await ethers.provider.getBlock();
      await expect(fixedRental.connect(Alice).stopLend(tokenId, lendingId))
            .to.emit(fixedRental, "StopLend")
            .withArgs(lendingId, block.timestamp + 1)
    });
  });
});

