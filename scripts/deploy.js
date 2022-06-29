// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers, upgrades } = require("hardhat");
require("dotenv").config()

async function main() {
  const [deployer] = await ethers.getSigners();

  // Deploy social token implementation
  const CDOSocialToken = await ethers.getContractFactory("CDOSocialToken");
  const socialTokenImplementation = await CDOSocialToken.deploy();
  await socialTokenImplementation.deployed();

  console.log("Social token implementation address:", socialTokenImplementation.address);

  // Deploy social token implementation
  const CDOBondingCurve = await ethers.getContractFactory("CDOBondingCurve");
  const poolImplementation = await CDOBondingCurve.deploy();
  await poolImplementation.deployed();

  console.log("Pool implementation address:", poolImplementation.address);

  // Deploy factory
  const Factory = await ethers.getContractFactory("CDOFactory");
  const factory = await Factory.deploy(
    socialTokenImplementation.address, poolImplementation.address, deployer.address, deployer.address, 1000);
  await factory.deployed();

  console.log("Factory address:", factory.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
