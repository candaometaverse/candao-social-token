// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./token/CDOPersonalToken.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

contract CDOBondingCurve is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for ERC20Upgradeable;
    using SafeERC20Upgradeable for CDOPersonalToken;
    using SafeMathUpgradeable for uint256;
    using ABDKMath64x64 for int128;

    uint256 public constant INITIAL_SUPPLY = 10 ** 18;
    uint16 public constant FEE_BASE = 10000;
    uint8 public constant PROTOCOL_PERCENTAGE_FEE = 50;

    int128 private constant _POWER_DIVIDER = 3 << 64;
    int128 private constant _DIVIDER = 1000 << 64;
    int128 private constant _AVG_DIVIDER = 2 << 64;
    uint256 private constant _DECIMALS = 10 ** 18;

    string private constant ERROR_ADDRESS = "CDOPersonalToken: invalid address";
    string private constant ERROR_NOT_ACTIVE = "CDOPersonalToken: pool is not active";

    CDOPersonalToken public personalToken;
    address public protocolFeeReceiver;
    address public usdtToken;

    bool public isActive;
    uint256 public marketCap;
    uint256 public currentPrice;
    uint256 public ownerTreasuryAmount;
    uint256 public protocolTreasuryAmount;
    // The fee is in 0.01% units, so value 30 means 0.3%.
    uint256 public transactionFee;

    event BuyPersonalTokens(
        address indexed buyer,
        uint256 indexed buyAmount,
        uint256 indexed buyPrice,
        uint256 fee
    );
    event SellPersonalTokens(
        address indexed seller,
        uint256 indexed sellAmount,
        uint256 indexed sellPrice,
        uint256 fee
    );

    /**
     * @dev Initialize market maker
     * @param personalTokenAddress The address of CDOPersonalToken contract
     * @param protocolFeeReceiverAddress The address for all protocol fees
     * @param usdtTokenAddress The address of payment token for personal tokens
     */
    function initialize(
        address personalTokenAddress,
        address protocolFeeReceiverAddress,
        address usdtTokenAddress,
        uint256 transactionFeeValue
    ) initializer public {
        require(_addressIsValid(personalTokenAddress), ERROR_ADDRESS);
        require(_addressIsValid(protocolFeeReceiverAddress), ERROR_ADDRESS);
        require(_addressIsValid(usdtTokenAddress), ERROR_ADDRESS);

        personalToken = CDOPersonalToken(personalTokenAddress);
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
        require(!isActive, "CDOPersonalToken: pool is already activated");

        personalToken.mint(address(this), INITIAL_SUPPLY);
        isActive = true;
    }

    /**
     * @dev Buy certain amount of personal tokens.
     */
    function buy(uint256 amount) external {
        require(isActive, ERROR_NOT_ACTIVE);

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

        // Mint personal tokens for buyer
        personalToken.mint(_msgSender(), amount);

        // Update state
        marketCap = marketCap.add(price);
        protocolTreasuryAmount = protocolTreasuryAmount.add(protocolFee);
        ownerTreasuryAmount = ownerTreasuryAmount.add(ptFee);
        currentPrice = tokenPrice;

        emit BuyPersonalTokens(_msgSender(), amount, currentPrice, fee);
    }

    /**
     * @dev Sell certain amount of personal tokens.
     */
    function sell(uint256 amount) external {
        require(isActive, ERROR_NOT_ACTIVE);

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
        personalToken.burnFrom(_msgSender(), amount);

        // Update state
        marketCap = marketCap.sub(price);
        protocolTreasuryAmount = protocolTreasuryAmount.add(protocolFee);
        ownerTreasuryAmount = ownerTreasuryAmount.add(ptFee);
        currentPrice = tokenPrice;

        emit SellPersonalTokens(_msgSender(), amount, currentPrice, fee);
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
        uint256 totalSupply = personalToken.totalSupply();
        uint256 nextTotalSupply = totalSupply.add(amount);
        int128 price = _price(ABDKMath64x64.divu(totalSupply, _DECIMALS), ABDKMath64x64.divu(nextTotalSupply, _DECIMALS));
        return ABDKMath64x64.mulu(price, _DECIMALS);
    }

    /**
     * @dev Calculates the sell price of the token
     * @param amount of tokens to sell
     */
    function calculateSellPrice(uint256 amount) public view returns (uint256) {
        uint256 totalSupply = personalToken.totalSupply();
        uint256 nextTotalSupply = totalSupply.sub(amount);
        int128 price = _price(ABDKMath64x64.divu(totalSupply, _DECIMALS), ABDKMath64x64.divu(nextTotalSupply, _DECIMALS));
        return ABDKMath64x64.mulu(price, _DECIMALS);
    }

    /**
     * @dev Calculates the price using the logarithmic bonding curve algorithm.
     * Calculates equation ( x^(1/3)/1000 + y^(1/3)/1000 ) / 2
     */
    function _price(int128 x, int128 y) public pure returns (int128) {
        return (_power(x).div(_DIVIDER).add(_power(y).div(_DIVIDER))).div(_AVG_DIVIDER);
    }

    /**
     * @dev Calculates x^(1/3), which is equivalent to e^(ln(x)/3)
     */
    function _power(int128 x) public pure returns (int128) {
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
