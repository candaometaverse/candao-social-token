const {expect} = require("chai");
const {ethers, upgrades} = require("hardhat");

describe("Bonding Curve", function () {

  let token;
  let usdtToken;
  let bondingCurve;
  const DELTA = 1000;

  beforeEach(async function () {
    const [_, ptTreasury, protocolTreasury, user] = await ethers.getSigners();

    // Deploy USDT token
    const TetherUSDToken = await ethers.getContractFactory("TetherUSD");
    usdtToken = await TetherUSDToken.deploy();

    // Transfer 10 mln tokens to user
    (await usdtToken.transfer(user.address, ethers.utils.parseUnits("10000000"))).wait();

    // Deploy personal token
    const CDOPersonalToken = await ethers.getContractFactory("CDOPersonalToken");
    token = await upgrades.deployProxy(CDOPersonalToken, ['CDOPersonalToken', 'CDO']);

    // Deploy bounding curve
    const CDOBondingCurve = await ethers.getContractFactory("CDOBondingCurve");
    bondingCurve = await CDOBondingCurve.deploy(token.address, ptTreasury.address, protocolTreasury.address, usdtToken.address);
  });

  it("Should instantiate bonding curve", async function () {
    const [_, ptTreasury, protocolTreasury] = await ethers.getSigners();
    expect(await bondingCurve.isActive()).to.equal(false);
    expect(await bondingCurve.token()).to.equal(token.address);
    expect(await bondingCurve.ptTreasury()).to.equal(ptTreasury.address);
    expect(await bondingCurve.protocolTreasury()).to.equal(protocolTreasury.address);
    expect(await bondingCurve.currentPrice()).to.equal(0);
    expect(await bondingCurve.ptTreasuryAmount()).to.equal(0);
    expect(await bondingCurve.protocolTreasuryAmount()).to.equal(0);
  });

  it("Should activate bonding curve", async function () {
    // Set activation role to bounding curve
    (await token.setupActivateRole(bondingCurve.address)).wait();

    // Activate bonding curve pool
    (await bondingCurve.activate()).wait();

    // Checking state after activation
    expect(await token.totalSupply()).to.equal(ethers.utils.parseUnits("1"));
    expect(await token.balanceOf(bondingCurve.address)).to.equal(ethers.utils.parseUnits("1"));
    expect(await usdtToken.balanceOf(bondingCurve.address)).to.equal(0);
    expect(await bondingCurve.isActive()).to.equal(true);
    expect(await bondingCurve.currentPrice()).to.equal(0);
    expect(await bondingCurve.ptTreasuryAmount()).to.equal(0);
    expect(await bondingCurve.protocolTreasuryAmount()).to.equal(0);
  });

  it("Should calculate BUY price", async function () {
    // Set activation role to bounding curve
    (await token.setupActivateRole(bondingCurve.address)).wait();

    // Activate bonding curve pool
    (await bondingCurve.activate()).wait();

    // Calculate buy price
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("0.001")))
      .to.closeTo(ethers.utils.parseUnits("0.001000166611141950"), DELTA);
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("1")))
      .to.closeTo(ethers.utils.parseUnits("0.001129960524947440"), DELTA);
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("1000")))
      .to.closeTo(ethers.utils.parseUnits("0.005501666111419550"), DELTA);
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("2000")))
      .to.closeTo(ethers.utils.parseUnits("0.006800655008742170"), DELTA);
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("3000")))
      .to.closeTo(ethers.utils.parseUnits("0.007712049012287050"), DELTA);
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("5000")))
      .to.closeTo(ethers.utils.parseUnits("0.009050449687370470"), DELTA);
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("1000000")))
      .to.closeTo(ethers.utils.parseUnits("0.050500016666661100"), DELTA);
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("1000000000")))
      .to.closeTo(ethers.utils.parseUnits("0.500500000166666000"), DELTA);
  });

  it("Should calculate SELL price", async function () {
    // Set activation role to bounding curve
    (await token.setupActivateRole(bondingCurve.address)).wait();

    // Activate bonding curve pool
    (await bondingCurve.activate()).wait();

    // Buy 1 mln tokens
    const [, , , user] = await ethers.getSigners();
    await usdtToken.connect(user).increaseAllowance(bondingCurve.address, "50500016666661111000000" + "151500049999983333000");
    (await bondingCurve.connect(user).buy(ethers.utils.parseUnits("1000000"))).wait();

    expect(await token.totalSupply()).to.equal(ethers.utils.parseEther("1000001"));

    // Calculate sell price
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("0.001")))
      .to.closeTo(ethers.utils.parseUnits("0.100000033316656000"), DELTA);
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("1")))
      .to.closeTo(ethers.utils.parseUnits("0.100000016666661000"), DELTA);
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("1000")))
      .to.closeTo(ethers.utils.parseUnits("0.099983361119131900"), DELTA);
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("2000")))
      .to.closeTo(ethers.utils.parseUnits("0.099966677775301600"), DELTA);
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("3000")))
      .to.closeTo(ethers.utils.parseUnits("0.099949983283238700"), DELTA);
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("5000")))
      .to.closeTo(ethers.utils.parseUnits("0.099916560779794800"), DELTA);
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("1000000")))
      .to.closeTo(ethers.utils.parseUnits("0.050500016666661100"), DELTA);
  });
});
