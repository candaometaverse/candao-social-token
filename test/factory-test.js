const {expect} = require("chai");
const {ethers} = require("hardhat");

describe("Factory", function () {

  let factory;
  let personalTokenImplementation;
  let poolImplementation;
  let usdtToken;

  beforeEach(async function () {
    const [_, , protocolFeeReceiver] = await ethers.getSigners();

    // Deploy USDT token
    const TetherUSDToken = await ethers.getContractFactory("TetherUSD");
    usdtToken = await TetherUSDToken.deploy();

    // Deploy personal token implementation
    const CDOPersonalToken = await ethers.getContractFactory("CDOPersonalToken");
    personalTokenImplementation = await CDOPersonalToken.deploy();

    // Deploy personal token implementation
    const CDOBondingCurve = await ethers.getContractFactory("CDOBondingCurve");
    poolImplementation = await CDOBondingCurve.deploy();

    // Deploy factory
    const Factory = await ethers.getContractFactory("CDOFactory");
    factory = await Factory.deploy(personalTokenImplementation.address, poolImplementation.address, protocolFeeReceiver.address);
  });

  it("Should instantiate factory", async function () {
    const [_, , protocolFeeReceiver] = await ethers.getSigners();

    expect(await factory.protocolFeeReceiver()).to.equal(protocolFeeReceiver.address);
    expect(await factory.personalTokenImplementation()).to.equal(personalTokenImplementation.address);
    expect(await factory.personalTokenPoolImplementation()).to.equal(poolImplementation.address);
  });

  it("Should create personal token", async function () {
    const [_, personalTokenCreator, protocolFeeReceiver] = await ethers.getSigners();

    let tx = await factory.connect(personalTokenCreator).createPersonalToken("TEST TOKEN", "TST", usdtToken.address, 50)
    let res = await tx.wait();

    let event = res.events?.filter((x) => {return x.event === "CreatePersonalToken"})[0];
    let tokenAddress = event['args'][1]
    let poolAddress = event['args'][2]

    const CDOPersonalToken = await ethers.getContractFactory("CDOPersonalToken");
    let token = CDOPersonalToken.attach(tokenAddress);

    const CDOBondingCurve = await ethers.getContractFactory("CDOBondingCurve");
    let pool = CDOBondingCurve.attach(poolAddress);

    expect(await token.name()).to.equal("TEST TOKEN");
    expect(await token.symbol()).to.equal("TST");
    expect(await token.totalSupply()).to.equal(0);
    expect(await token.owner()).to.equal(poolAddress);

    expect(await pool.isActive()).to.equal(false);
    expect(await pool.personalToken()).to.equal(token.address);
    expect(await pool.owner()).to.equal(personalTokenCreator.address);
    expect(await pool.protocolFeeReceiver()).to.equal(protocolFeeReceiver.address);
    expect(await pool.currentPrice()).to.equal(0);
    expect(await pool.ownerTreasuryAmount()).to.equal(0);
    expect(await pool.protocolTreasuryAmount()).to.equal(0);
  });
});