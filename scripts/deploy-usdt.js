// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
require("dotenv").config()

async function main() {
  // Deploy social token implementation
  const TetherUSD = await ethers.getContractFactory("TetherUSD");
  const token = await TetherUSD.deploy();
  await token.deployed();

  console.log("USDT token address:", token.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
