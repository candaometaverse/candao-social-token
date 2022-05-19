const { expect } = require("chai");
const { ethers, upgrades} = require("hardhat");

describe("Bonding Curve", function () {
  it("Should instantiate bonding curve", async function () {
    const [_, ptTreasury, protocolTreasury] = await ethers.getSigners();

    // Deploy USDT token
    const TetherUSDToken = await ethers.getContractFactory("TetherUSD");
    const usdtToken = await TetherUSDToken.deploy();

    // Deploy personal token
    const CDOPersonalToken = await ethers.getContractFactory("CDOPersonalToken");
    const token = await upgrades.deployProxy(CDOPersonalToken, ['CDOPersonalToken', 'CDO']);

    // Deploy bounding curve
    const CDOBondingCurve = await ethers.getContractFactory("CDOBondingCurve");
    const bondingCurve = await CDOBondingCurve.deploy(token.address, ptTreasury.address, protocolTreasury.address, usdtToken.address);

    expect(await bondingCurve.isOpen()).to.equal(false);
    expect(await bondingCurve.token()).to.equal(token.address);
    expect(await bondingCurve.PT_treasury()).to.equal(ptTreasury.address);
    expect(await bondingCurve.Protocol_treasury()).to.equal(protocolTreasury.address);
    expect(await bondingCurve.currentPrice()).to.equal(0);
    expect(await bondingCurve.ptTreasuryAmount()).to.equal(0);
    expect(await bondingCurve.protocolTreasuryAmount()).to.equal(0);
  });

  it("Should activate bonding curve", async function () {
    const [owner, ptTreasury, protocolTreasury] = await ethers.getSigners();

    // Deploy USDT token
    const TetherUSDToken = await ethers.getContractFactory("TetherUSD");
    const usdtToken = await TetherUSDToken.deploy();

    // Deploy personal token
    const CDOPersonalToken = await ethers.getContractFactory("CDOPersonalToken");
    const token = await upgrades.deployProxy(CDOPersonalToken, ['CDOPersonalToken', 'CDO']);

    // Deploy bounding curve
    const CDOBondingCurve = await ethers.getContractFactory("CDOBondingCurve");
    const bondingCurve = await CDOBondingCurve.deploy(token.address, ptTreasury.address, protocolTreasury.address, usdtToken.address);

    // Set activation role to bounding curve
    (await token.setupActivateRole(bondingCurve.address)).wait();

    // Activate bonding curve pool
    (await bondingCurve.activate(0)).wait();

    // Checking state after activation
    expect(await token.totalSupply()).to.equal("1000000000000000000");
    expect(await token.balanceOf(bondingCurve.address)).to.equal("1000000000000000000");
    expect(await usdtToken.balanceOf(bondingCurve.address)).to.equal(0);
    expect(await bondingCurve.isOpen()).to.equal(true);
    expect(await bondingCurve.currentPrice()).to.equal(0);
    expect(await bondingCurve.ptTreasuryAmount()).to.equal(0);
    expect(await bondingCurve.protocolTreasuryAmount()).to.equal(0);
  });
});
