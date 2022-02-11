// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const DirectRental = await hre.ethers.getContractFactory("DirectRental");
  const directRental = await DirectRental.deploy(
    "0xd35Db39aF0755AfFbF63E15162EB6923409d021e",
    "0xf62DF962140fB24FA74DbE15E8e8450a8d533245",
    "0x052f11157A23406F2A705fE78F2695009a6Ec022",
    "0x43ad0f0585659a68faA72FE276e48B9d2a23B117",
    10000
  );

  await directRental.deployed();

  console.log("DirectRental deployed to:", directRental.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
