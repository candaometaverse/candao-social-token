const {expect} = require("chai");
const {ethers} = require("hardhat");

describe("Factory", function () {

  let factory;
  let socialTokenImplementation;
  let poolImplementation;
  let usdtToken;

  beforeEach(async function () {
    const [_, , protocolFeeReceiver, marketingPool] = await ethers.getSigners();

    // Deploy USDT token
    const TetherUSDToken = await ethers.getContractFactory("TetherUSD");
    usdtToken = await TetherUSDToken.deploy();

    // Deploy social token implementation
    const CDOSocialToken = await ethers.getContractFactory("CDOSocialToken");
    socialTokenImplementation = await CDOSocialToken.deploy();

    // Deploy social token implementation
    const CDOBondingCurve = await ethers.getContractFactory("CDOBondingCurve");
    poolImplementation = await CDOBondingCurve.deploy();

    // Deploy factory
    const Factory = await ethers.getContractFactory("CDOFactory");
    factory = await Factory.deploy(
      socialTokenImplementation.address, poolImplementation.address, protocolFeeReceiver.address, marketingPool.address, 1000);
  });

  it("Should instantiate factory", async function () {
    const [_, , protocolFeeReceiver, marketingPool] = await ethers.getSigners();

    expect(await factory.protocolFeeReceiver()).to.equal(protocolFeeReceiver.address);
    expect(await factory.socialTokenImplementation()).to.equal(socialTokenImplementation.address);
    expect(await factory.socialTokenPoolImplementation()).to.equal(poolImplementation.address);
    expect(await factory.marketingPool()).to.equal(marketingPool.address);
    expect(await factory.minMarketingBudget()).to.equal(1000);
  });

  it("Should create social token", async function () {
    const [_, socialTokenCreator, protocolFeeReceiver] = await ethers.getSigners();

    let tx = await factory.connect(socialTokenCreator).createSocialToken("TEST TOKEN", "TST", 50)
    let res = await tx.wait();

    let event = res.events?.filter((x) => {return x.event === "CreateSocialToken"})[0];
    let tokenAddress = event['args'][1]
    let poolAddress = event['args'][2]

    const CDOSocialToken = await ethers.getContractFactory("CDOSocialToken");
    let token = CDOSocialToken.attach(tokenAddress);

    const CDOBondingCurve = await ethers.getContractFactory("CDOBondingCurve");
    let pool = CDOBondingCurve.attach(poolAddress);

    expect(await token.name()).to.equal("TEST TOKEN");
    expect(await token.symbol()).to.equal("TST");
    expect(await token.totalSupply()).to.equal(ethers.utils.parseUnits("1"));
    expect(await token.owner()).to.equal(poolAddress);

    expect(await pool.isActive()).to.equal(false);
    expect(await pool.socialToken()).to.equal(token.address);
    expect(await pool.owner()).to.equal(socialTokenCreator.address);
    expect(await pool.protocolFeeReceiver()).to.equal(protocolFeeReceiver.address);
    expect(await pool.currentPrice()).to.equal(0);
    expect(await pool.ownerTreasuryAmount()).to.equal(0);
    expect(await pool.protocolTreasuryAmount()).to.equal(0);
  });
});