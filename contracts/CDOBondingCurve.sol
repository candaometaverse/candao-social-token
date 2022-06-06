// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./token/CDOSocialToken.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

    error Unauthorized();
    error InvalidAddress();
    error NotActivePool();
    error PoolAlreadyActivated();

contract CDOBondingCurve is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for ERC20Upgradeable;
    using SafeERC20Upgradeable for CDOSocialToken;
    using SafeMathUpgradeable for uint256;
    using ABDKMath64x64 for int128;

    uint256 public constant INITIAL_SUPPLY = 10 ** 18;
    uint256 public constant FEE_BASE = 10000;
    uint256 public constant PROTOCOL_PERCENTAGE_FEE = 50;

    int128 private constant _POWER_DIVIDER = 3 << 64;
    int128 private constant _DIVIDER = 1000 << 64;
    int128 private constant _AVG_DIVIDER = 2 << 64;
    uint256 private constant _DECIMALS = 10 ** 18;

    CDOSocialToken public socialToken;
    address public protocolFeeReceiver;
    address public usdtToken;

    bool public isActive;
    uint256 public marketCap;
    uint256 public currentPrice;
    uint256 public ownerTreasuryAmount;
    uint256 public protocolTreasuryAmount;
    // The fee is in 0.01% units, so value 30 means 0.3%.
    uint256 public transactionFee;

    event BuySocialTokens(
        address indexed buyer,
        uint256 indexed buyAmount,
        uint256 indexed buyPrice,
        uint256 fee
    );
    event SellSocialTokens(
        address indexed seller,
        uint256 indexed sellAmount,
        uint256 indexed sellPrice,
        uint256 fee
    );

    /**
     * @dev Initialize market maker
     * @param socialTokenAddress The address of CDOsocialToken contract
     * @param protocolFeeReceiverAddress The address for all protocol fees
     * @param usdtTokenAddress The address of payment token for social tokens
     */
    function initialize(
        address socialTokenAddress,
        address protocolFeeReceiverAddress,
        address usdtTokenAddress,
        uint256 transactionFeeValue
    ) public initializer {
        if (!_addressIsValid(socialTokenAddress))
            revert InvalidAddress();
        if (!_addressIsValid(protocolFeeReceiverAddress))
            revert InvalidAddress();
        if (!_addressIsValid(usdtTokenAddress))
            revert InvalidAddress();

        socialToken = CDOSocialToken(socialTokenAddress);
        protocolFeeReceiver = protocolFeeReceiverAddress;
        usdtToken = usdtTokenAddress;
        transactionFee = transactionFeeValue;
        __Ownable_init();
    }

    /**
     * @dev Activate the pool, it unlocks buy and sell operations.
     * It can be called only once.
     */
    function activate() external onlyOwner() {
        if (isActive)
            revert PoolAlreadyActivated();

        socialToken.mint(address(this), INITIAL_SUPPLY);
        isActive = true;
    }

    /**
     * @dev Buy certain amount of social tokens.
     */
    function buy(uint256 amount) external {
        if (!isActive)
            revert NotActivePool();

        // Calculate deposit and fees
        uint256 tokenPrice = calculateBuyPrice(amount);
        uint256 price = amount.mul(tokenPrice).div(_DECIMALS);
        uint256 fee = price.mul(transactionFee).div(FEE_BASE);
        uint256 protocolFee = fee.mul(PROTOCOL_PERCENTAGE_FEE).div(100);
        uint256 ptFee = fee.sub(protocolFee);

        // Transfer USDT tokens
        ERC20Upgradeable(usdtToken).safeTransferFrom(_msgSender(), address(this), price);
        ERC20Upgradeable(usdtToken).safeTransferFrom(_msgSender(), protocolFeeReceiver, protocolFee);
        ERC20Upgradeable(usdtToken).safeTransferFrom(_msgSender(), owner(), ptFee);

        // Mint social tokens for buyer
        socialToken.mint(_msgSender(), amount);

        // Update state
        marketCap = marketCap.add(price);
        protocolTreasuryAmount = protocolTreasuryAmount.add(protocolFee);
        ownerTreasuryAmount = ownerTreasuryAmount.add(ptFee);
        currentPrice = tokenPrice;

        emit BuySocialTokens(_msgSender(), amount, currentPrice, fee);
    }

    /**
     * @dev Sell certain amount of social tokens.
     */
    function sell(uint256 amount) external {
        if (!isActive)
            revert NotActivePool();

        // Calculate withdrawal and fees
        uint256 tokenPrice = calculateSellPrice(amount);
        uint256 price = amount.mul(tokenPrice).div(_DECIMALS);
        uint256 fee = price.mul(transactionFee).div(FEE_BASE);
        uint256 withdrawalAmount = price.sub(fee);
        uint256 protocolFee = fee.mul(PROTOCOL_PERCENTAGE_FEE).div(100);
        uint256 ptFee = fee.sub(protocolFee);

        // Transfer USDT tokens
        ERC20Upgradeable(usdtToken).safeTransfer(_msgSender(), withdrawalAmount);
        ERC20Upgradeable(usdtToken).safeTransfer(protocolFeeReceiver, protocolFee);
        ERC20Upgradeable(usdtToken).safeTransfer(owner(), ptFee);

        // Burn tokens
        socialToken.burnFrom(_msgSender(), amount);

        // Update state
        marketCap = marketCap.sub(price);
        protocolTreasuryAmount = protocolTreasuryAmount.add(protocolFee);
        ownerTreasuryAmount = ownerTreasuryAmount.add(ptFee);
        currentPrice = tokenPrice;

        emit SellSocialTokens(_msgSender(), amount, currentPrice, fee);
    }

    /**
     * @dev Set transaction fee can be called only by owner.
     * The fee is in 0.01% units, so value 30 means 0.3%.
     */
    function setTransactionFee(uint256 fee) external onlyOwner() {
        transactionFee = fee;
    }

    /**
     * @dev Calculates the purchase price of the token
     * @param amount of tokens to buy
     */
    function calculateBuyPrice(uint256 amount) public view returns (uint256) {
        uint256 totalSupply = socialToken.totalSupply();
        uint256 nextTotalSupply = totalSupply.add(amount);
        int128 price = _price(ABDKMath64x64.divu(totalSupply, _DECIMALS), ABDKMath64x64.divu(nextTotalSupply, _DECIMALS));
        return ABDKMath64x64.mulu(price, 10 ** ERC20Upgradeable(usdtToken).decimals());
    }

    /**
     * @dev Calculates the sell price of the token
     * @param amount of tokens to sell
     */
    function calculateSellPrice(uint256 amount) public view returns (uint256) {
        uint256 totalSupply = socialToken.totalSupply();
        uint256 nextTotalSupply = totalSupply.sub(amount);
        int128 price = _price(ABDKMath64x64.divu(totalSupply, _DECIMALS), ABDKMath64x64.divu(nextTotalSupply, _DECIMALS));
        return ABDKMath64x64.mulu(price, 10 ** ERC20Upgradeable(usdtToken).decimals());
    }

    /**
     * @dev Calculates deposit amount to send
     */
    function simulateBuy(uint256 amount) public view returns (uint256) {
        uint256 tokenPrice = calculateBuyPrice(amount);
        uint256 price = amount.mul(tokenPrice).div(_DECIMALS);
        uint256 fee = price.mul(transactionFee).div(FEE_BASE);
        return price.add(fee);
    }

    /**
     * @dev Calculates withdrawal amount
     */
    function simulateSell(uint256 amount) public view returns (uint256) {
        uint256 tokenPrice = calculateSellPrice(amount);
        uint256 price = amount.mul(tokenPrice).div(_DECIMALS);
        uint256 fee = price.mul(transactionFee).div(FEE_BASE);
        return price.sub(fee);
    }

    /**
     * @dev Calculates the price using the logarithmic bonding curve algorithm.
     * Calculates equation ( x^(1/3)/1000 + y^(1/3)/1000 ) / 2
     */
    function _price(int128 x, int128 y) internal pure returns (int128) {
        return (_power(x).div(_DIVIDER).add(_power(y).div(_DIVIDER))).div(_AVG_DIVIDER);
    }

    /**
     * @dev Calculates x^(1/3), which is equivalent to e^(ln(x)/3)
     */
    function _power(int128 x) internal pure returns (int128) {
        // e^(ln(x)/3)
        return (x.ln().div(_POWER_DIVIDER)).exp();
    }

    /**
     * @dev Checks if address is not empty
     */
    function _addressIsValid(address _addr) internal pure returns (bool) {
        return _addr != address(0);
    }
}
