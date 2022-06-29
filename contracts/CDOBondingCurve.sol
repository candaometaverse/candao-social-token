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
    error InvalidTransactionFeeValue();
    error InvalidMinimumMarketingBudgetValue();
    error TooLowMarketingBudget();
    error TooHighMarketingBudgetValue();

contract CDOBondingCurve is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for ERC20Upgradeable;
    using SafeERC20Upgradeable for CDOSocialToken;
    using SafeMathUpgradeable for uint256;
    using ABDKMath64x64 for int128;

    uint256 public constant MAX_BASE = 10000;
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
    // The fee is in 0.01% units, so value 100 means 1%.
    uint256 public transactionFee;
    // The marketing budget is in 0.01% units, so value 100 means 1%.
    uint256 public marketingBudget;
    uint256 public minMarketingBudget;
    address public marketingPool;

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
     * @param transactionFeeValue all buy/sell transactions fee value
     */
    function initialize(
        address socialTokenAddress,
        address protocolFeeReceiverAddress,
        uint256 transactionFeeValue,
        address marketingPoolAddress,
        uint256 minMarketingBudgetValue
    ) public initializer {
        if (!_addressIsValid(socialTokenAddress))
            revert InvalidAddress();
        if (!_addressIsValid(protocolFeeReceiverAddress))
            revert InvalidAddress();
        if (!_addressIsValid(marketingPoolAddress))
            revert InvalidAddress();
        if (minMarketingBudgetValue > MAX_BASE)
            revert InvalidMinimumMarketingBudgetValue();
        if (transactionFeeValue > MAX_BASE)
            revert InvalidTransactionFeeValue();

        socialToken = CDOSocialToken(socialTokenAddress);
        protocolFeeReceiver = protocolFeeReceiverAddress;
        transactionFee = transactionFeeValue;
        marketingPool = marketingPoolAddress;
        minMarketingBudget = minMarketingBudgetValue;
        __Ownable_init();
    }

    /**
     * @dev Activate the pool, it unlocks buy and sell operations.
     * It can be called only once.
     */
    function activate(address usdtTokenAddress, uint256 amountToBuy, uint256 marketingBudgetValue) external onlyOwner() {
        if (!_addressIsValid(usdtTokenAddress))
            revert InvalidAddress();
        if (isActive)
            revert PoolAlreadyActivated();
        if (marketingBudgetValue < minMarketingBudget)
            revert TooLowMarketingBudget();
        if (marketingBudgetValue > MAX_BASE)
            revert TooHighMarketingBudgetValue();

        usdtToken = usdtTokenAddress;
        isActive = true;
        marketingBudget = marketingBudgetValue;

        // Buy first social tokens
        _buy(amountToBuy, address(this));

        // Transfer marketing budget to marketing pool
        uint256 marketingBudgetAmount = amountToBuy.mul(marketingBudgetValue).div(MAX_BASE);
        ERC20Upgradeable(socialToken).safeTransfer(marketingPool, marketingBudgetAmount);

        // Transfer rest to message sender
        ERC20Upgradeable(socialToken).safeTransfer(_msgSender(), amountToBuy - marketingBudgetAmount);
    }

    /**
     * @dev Buy certain amount of social tokens.
     */
    function buy(uint256 amount) external {
        _buy(amount, _msgSender());
    }


    /**
     * @dev Buy certain amount of social tokens for recipient.
     */
    function _buy(uint256 amount, address recipient) internal {
        if (!isActive)
            revert NotActivePool();
        if (amount == 0)
            return;

        // Calculate deposit and fees
        uint256 tokenPrice = calculateBuyPrice(amount);
        uint256 price = amount.mul(tokenPrice).div(_DECIMALS);
        uint256 fee = price.mul(transactionFee).div(MAX_BASE);
        uint256 protocolFee = fee.mul(PROTOCOL_PERCENTAGE_FEE).div(100);
        uint256 ptFee = fee.sub(protocolFee);

        // Transfer USDT tokens
        ERC20Upgradeable(usdtToken).safeTransferFrom(_msgSender(), address(this), price);
        ERC20Upgradeable(usdtToken).safeTransferFrom(_msgSender(), protocolFeeReceiver, protocolFee);
        ERC20Upgradeable(usdtToken).safeTransferFrom(_msgSender(), owner(), ptFee);

        // Mint social tokens for recipient
        socialToken.mint(recipient, amount);

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
        if (amount == 0)
            return;

        // Calculate withdrawal and fees
        uint256 tokenPrice = calculateSellPrice(amount);
        uint256 price = amount.mul(tokenPrice).div(_DECIMALS);
        uint256 fee = price.mul(transactionFee).div(MAX_BASE);
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
        return _calculateBuyPrice(amount, usdtToken);
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
        uint256 fee = price.mul(transactionFee).div(MAX_BASE);
        return price.add(fee);
    }

    /**
    * @dev Calculates deposit amount to send during activation
     */
    function simulateActivationBuy(uint256 amount, address usdtTokenAddress) public view returns (uint256) {
        uint256 tokenPrice = _calculateBuyPrice(amount, usdtTokenAddress);
        uint256 price = amount.mul(tokenPrice).div(_DECIMALS);
        uint256 fee = price.mul(transactionFee).div(MAX_BASE);
        return price.add(fee);
    }

    /**
     * @dev Calculates withdrawal amount
     */
    function simulateSell(uint256 amount) public view returns (uint256) {
        uint256 tokenPrice = calculateSellPrice(amount);
        uint256 price = amount.mul(tokenPrice).div(_DECIMALS);
        uint256 fee = price.mul(transactionFee).div(MAX_BASE);
        return price.sub(fee);
    }

    /**
     * @dev Calculates the purchase price of the social token
     * @param amount of social tokens to buy
     * @param usdtTokenAddress the token to pay with
     */
    function _calculateBuyPrice(uint256 amount, address usdtTokenAddress) internal view returns (uint256) {
        uint256 totalSupply = socialToken.totalSupply();
        uint256 nextTotalSupply = totalSupply.add(amount);
        int128 price = _price(ABDKMath64x64.divu(totalSupply, _DECIMALS), ABDKMath64x64.divu(nextTotalSupply, _DECIMALS));
        return ABDKMath64x64.mulu(price, 10 ** ERC20Upgradeable(usdtTokenAddress).decimals());
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
