const {expect} = require("chai");
const {ethers, upgrades} = require("hardhat");

describe("Bonding Curve", function () {

  let token;
  let usdtToken;
  let bondingCurve;
  const DELTA = 1;

  beforeEach(async function () {
    const [_, personalTokenCreator, protocolAdmin, user] = await ethers.getSigners();

    // Deploy USDT token
    const TetherUSDToken = await ethers.getContractFactory("TetherUSD");
    usdtToken = await TetherUSDToken.deploy();

    // Transfer 10 mln tokens to user
    (await usdtToken.transfer(user.address, ethers.utils.parseUnits("10000000", 6))).wait();

    // Deploy personal token
    const CDOPersonalToken = await ethers.getContractFactory("CDOPersonalToken");
    token = await upgrades.deployProxy(CDOPersonalToken, ['CDOPersonalToken', 'CDO']);

    // Deploy bounding curve
    const CDOBondingCurve = await ethers.getContractFactory("CDOBondingCurve");
    bondingCurve = await upgrades.deployProxy(CDOBondingCurve.connect(personalTokenCreator),
      [token.address, protocolAdmin.address, usdtToken.address, 30]);

    // Transfer token ownership to the CDOBondingCurve pool
    (await token.transferOwnership(bondingCurve.address)).wait();
  });

  it("Should instantiate bonding curve", async function () {
    const [_, personalTokenCreator, protocolFeeReceiver] = await ethers.getSigners();
    expect(await bondingCurve.isActive()).to.equal(false);
    expect(await bondingCurve.personalToken()).to.equal(token.address);
    expect(await bondingCurve.owner()).to.equal(personalTokenCreator.address);
    expect(await bondingCurve.protocolFeeReceiver()).to.equal(protocolFeeReceiver.address);
    expect(await bondingCurve.currentPrice()).to.equal(0);
    expect(await bondingCurve.ownerTreasuryAmount()).to.equal(0);
    expect(await bondingCurve.protocolTreasuryAmount()).to.equal(0);
  });

  it("Should activate bonding curve", async function () {
    // Activate bonding curve pool
    const [_, personalTokenCreator] = await ethers.getSigners();
    (await bondingCurve.connect(personalTokenCreator).activate()).wait();

    // Checking state after activation
    expect(await token.totalSupply()).to.equal(ethers.utils.parseUnits("1"));
    expect(await token.balanceOf(bondingCurve.address)).to.equal(ethers.utils.parseUnits("1"));
    expect(await usdtToken.balanceOf(bondingCurve.address)).to.equal(0);
    expect(await bondingCurve.isActive()).to.equal(true);
    expect(await bondingCurve.currentPrice()).to.equal(0);
    expect(await bondingCurve.ownerTreasuryAmount()).to.equal(0);
    expect(await bondingCurve.protocolTreasuryAmount()).to.equal(0);
  });

  it("Should calculate BUY price", async function () {
    // Activate bonding curve pool
    const [_, personalTokenCreator] = await ethers.getSigners();
    (await bondingCurve.connect(personalTokenCreator).activate()).wait();

    // Calculate buy price
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("0.001")))
      .to.equal(ethers.utils.parseUnits("0.001000", 6));
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("1")))
      .to.equal(ethers.utils.parseUnits("0.001129", 6));
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("1000")))
      .to.equal(ethers.utils.parseUnits("0.005501", 6));
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("2000")))
      .to.equal(ethers.utils.parseUnits("0.006800", 6));
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("3000")))
      .to.equal(ethers.utils.parseUnits("0.007712", 6));
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("5000")))
      .to.equal(ethers.utils.parseUnits("0.009050", 6));
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("1000000")))
      .to.equal(ethers.utils.parseUnits("0.050500", 6));
    expect(await bondingCurve.calculateBuyPrice(ethers.utils.parseUnits("1000000000")))
      .to.equal(ethers.utils.parseUnits("0.500500", 6));
  });

  it("Should calculate SELL price", async function () {
    // Activate bonding curve pool
    const [, personalTokenCreator,,user] = await ethers.getSigners();
    (await bondingCurve.connect(personalTokenCreator).activate()).wait();

    // Buy 1 mln tokens
    await usdtToken.connect(user).increaseAllowance(bondingCurve.address, "50651500000");
    (await bondingCurve.connect(user).buy(ethers.utils.parseUnits("1000000"))).wait();

    expect(await token.totalSupply()).to.equal(ethers.utils.parseEther("1000001"));

    // Calculate sell price
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("0.001")))
      .to.equal(ethers.utils.parseUnits("0.100000", 6));
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("1")))
      .to.equal(ethers.utils.parseUnits("0.100000", 6));
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("1000")))
      .to.equal(ethers.utils.parseUnits("0.099983", 6));
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("2000")))
      .to.equal(ethers.utils.parseUnits("0.099966", 6));
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("3000")))
      .to.equal(ethers.utils.parseUnits("0.099949", 6));
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("5000")))
      .to.equal(ethers.utils.parseUnits("0.099916", 6));
    expect(await bondingCurve.calculateSellPrice(ethers.utils.parseUnits("1000000")))
      .to.equal(ethers.utils.parseUnits("0.050500", 6));
  });

  it("Should BUY and SELL tokens", async function () {
    // Activate bonding curve pool
    const [_, personalTokenCreator,protocolAdmin,user] = await ethers.getSigners();
    (await bondingCurve.connect(personalTokenCreator).activate()).wait();

    // Buy 1000 tokens
    let depositAmount = await bondingCurve.simulateBuy(ethers.utils.parseUnits("1000"));
    await usdtToken.connect(user).increaseAllowance(bondingCurve.address, depositAmount);
    (await bondingCurve.connect(user).buy(ethers.utils.parseUnits("1000"))).wait();

    // Checking state
    expect(await token.totalSupply()).to.equal(ethers.utils.parseUnits("1001"));
    expect(await bondingCurve.marketCap()).to.equal(ethers.utils.parseUnits("5.501000", 6));
    expect(await bondingCurve.ownerTreasuryAmount()).to.equal(ethers.utils.parseUnits("0.008252", 6));
    expect(await bondingCurve.protocolTreasuryAmount()).to.equal(ethers.utils.parseUnits("0.008251",6));
    expect(await usdtToken.balanceOf(personalTokenCreator.address)).to.equal(ethers.utils.parseUnits("0.008252", 6));
    expect(await usdtToken.balanceOf(protocolAdmin.address)).to.equal(ethers.utils.parseUnits("0.008251", 6));

    // Buy 2000 tokens
    depositAmount = await bondingCurve.simulateBuy(ethers.utils.parseUnits("2000"));
    await usdtToken.connect(user).increaseAllowance(bondingCurve.address, depositAmount);
    (await bondingCurve.connect(user).buy(ethers.utils.parseUnits("2000"))).wait();

    // Checking state
    expect(await token.totalSupply()).to.equal(ethers.utils.parseUnits("3001"));
    expect(await bondingCurve.marketCap()).to.equal(ethers.utils.parseUnits("29.927000", 6));
    expect(await bondingCurve.ownerTreasuryAmount()).to.equal(ethers.utils.parseUnits("0.044891", 6));
    expect(await bondingCurve.protocolTreasuryAmount()).to.equal(ethers.utils.parseUnits("0.044890", 6));
    expect(await usdtToken.balanceOf(personalTokenCreator.address)).to.equal(ethers.utils.parseUnits("0.044891", 6));
    expect(await usdtToken.balanceOf(protocolAdmin.address)).to.equal(ethers.utils.parseUnits("0.044890", 6));

    // Sell 1000 token
    await token.connect(user).increaseAllowance(bondingCurve.address, ethers.utils.parseUnits("1000"));
    (await bondingCurve.connect(user).sell(ethers.utils.parseUnits("1000"))).wait();

    // Checking state
    expect(await token.totalSupply()).to.equal(ethers.utils.parseUnits("2001"));
    expect(await bondingCurve.marketCap()).to.equal(ethers.utils.parseUnits("16.415000", 6));
    expect(await bondingCurve.ownerTreasuryAmount()).to.equal(ethers.utils.parseUnits("0.065159", 6));
    expect(await bondingCurve.protocolTreasuryAmount()).to.equal(ethers.utils.parseUnits("0.065158", 6));
    expect(await token.balanceOf(user.address)).to.equal(ethers.utils.parseUnits("2000"));
  });

  it("Should configure transaction FEE", async function () {
    // Activate bonding curve pool
    const [_, personalTokenCreator,,user] = await ethers.getSigners();
    (await bondingCurve.connect(personalTokenCreator).activate()).wait();

    // Set transaction fee
    (await bondingCurve.connect(personalTokenCreator).setTransactionFee(300)).wait();

    // Buy 1000 tokens
    let depositAmount = await bondingCurve.simulateBuy(ethers.utils.parseUnits("1000"));
    await usdtToken.connect(user).increaseAllowance(bondingCurve.address, depositAmount);
    (await bondingCurve.connect(user).buy(ethers.utils.parseUnits("1000"))).wait();
    expect(await bondingCurve.ownerTreasuryAmount()).to.equal(ethers.utils.parseUnits("0.082515", 6));
    expect(await bondingCurve.protocolTreasuryAmount()).to.equal(ethers.utils.parseUnits("0.082515", 6));
  });
});
