// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers, upgrades } = require("hardhat");
require("dotenv").config()

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const CDOPersonalToken = await ethers.getContractFactory("CDOPersonalToken");
  const cdoPT = await upgrades.deployProxy(CDOPersonalToken, ['CDOPersonalToken', 'CDO']);

  await cdoPT.deployed();
  console.log("CDOPersonalToken deployed to:", cdoPT.address);

  const CDOBondingCurve = await ethers.getContractFactory("CDOBondingCurve");
  const bondingcurve_instance = await CDOBondingCurve.deploy(cdoPT.address, process.env.PT_TREASURY, process.env.PROTOCOL_TREASURY, process.env.USDT_ADDRESS);

  console.log("CDO Bonding Curve deployed to:", bondingcurve_instance.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
