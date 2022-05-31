// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./token/v1/CDOPersonalToken.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

contract CDOBondingCurve is AccessControl, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using SafeERC20 for CDOPersonalToken;
    using SafeMath for uint256;
    using ABDKMath64x64 for int128;

    uint256 public constant INITIAL_SUPPLY = 10 ** 18;
    uint8 public constant FEE = 30;
    uint16 public constant FEE_BASE = 10000;
    uint8 public constant PROTOCOL_PERCENTAGE_FEE = 50;

    int128 private constant _POWER_DIVIDER = 3 << 64;
    int128 private constant _DIVIDER = 1000 << 64;
    int128 private constant _AVG_DIVIDER = 2 << 64;
    uint256 private constant _DECIMALS = 10 ** 18;

    string private constant ERROR_ADDRESS = "MM_ADDRESS_IS_EOA";
    string private constant ERROR_NOT_ACTIVE = "MM_NOT_ACTIVE";

    CDOPersonalToken public token;
    address public ptTreasury;
    address public protocolTreasury;
    address public usdtToken;

    bool public isActive;
    uint256 public marketCap;
    uint256 public currentPrice;
    uint256 public ptTreasuryAmount;
    uint256 public protocolTreasuryAmount;

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
     * @notice Initialize market maker
     * @param _token The address of CDOPersonalToken contract
     * @param _ptTreasury The address of
     */
    constructor(
        address _token,
        address _ptTreasury,
        address _protocolTreasury,
        address _usdtToken
    ) {
        require(_addressIsValid(_ptTreasury), ERROR_ADDRESS);
        require(_addressIsValid(_protocolTreasury), ERROR_ADDRESS);
        require(_addressIsValid(_usdtToken), ERROR_ADDRESS);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        token = CDOPersonalToken(_token);
        ptTreasury = _ptTreasury;
        protocolTreasury = _protocolTreasury;
        usdtToken = _usdtToken;
    }

    function activate() external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "CDOPersonalToken: must have admin role to activate"
        );
        token.activate(INITIAL_SUPPLY);
        isActive = true;
    }

    function buy(uint256 amount) external nonReentrant {
        require(isActive, ERROR_NOT_ACTIVE);

        // Calculate deposit and fees
        uint256 tokenPrice = calculateBuyPrice(amount);
        uint256 price = amount.mul(tokenPrice).div(_DECIMALS);
        uint256 fee = price.mul(FEE).div(FEE_BASE);
        uint256 protocolFee = fee.mul(PROTOCOL_PERCENTAGE_FEE).div(100);
        uint256 ptFee = fee.sub(protocolFee);

        // Transfer USDT tokens
        ERC20(usdtToken).safeTransferFrom(_msgSender(), address(this), price);
        ERC20(usdtToken).safeTransferFrom(_msgSender(), protocolTreasury, protocolFee);
        ERC20(usdtToken).safeTransferFrom(_msgSender(), ptTreasury, ptFee);

        // Mint personal tokens for buyer
        token.mint(_msgSender(), amount);

        // Update state
        marketCap = marketCap.add(price);
        protocolTreasuryAmount = protocolTreasuryAmount.add(protocolFee);
        ptTreasuryAmount = ptTreasuryAmount.add(ptFee);
        currentPrice = tokenPrice;

        emit BuyPersonalTokens(_msgSender(), amount, currentPrice, fee);
    }

    function sell(uint256 amount) external nonReentrant {
        require(isActive, ERROR_NOT_ACTIVE);

        // Calculate withdrawal and fees
        uint256 tokenPrice = calculateSellPrice(amount);
        uint256 price = amount.mul(tokenPrice).div(_DECIMALS);
        uint256 fee = price.mul(FEE).div(FEE_BASE);
        uint256 withdrawalAmount = price.sub(fee);
        uint256 protocolFee = fee.mul(PROTOCOL_PERCENTAGE_FEE).div(100);
        uint256 ptFee = fee.sub(protocolFee);

        // Transfer USDT tokens
        ERC20(usdtToken).safeTransfer(_msgSender(), withdrawalAmount);
        ERC20(usdtToken).safeTransfer(protocolTreasury, protocolFee);
        ERC20(usdtToken).safeTransfer(ptTreasury, ptFee);

        // Burn tokens
        token.burnFrom(_msgSender(), amount);

        // Update state
        marketCap = marketCap.sub(price);
        protocolTreasuryAmount = protocolTreasuryAmount.add(protocolFee);
        ptTreasuryAmount = ptTreasuryAmount.add(ptFee);
        currentPrice = tokenPrice;

        emit SellPersonalTokens(_msgSender(), amount, currentPrice, fee);
    }

    function upgradeUSDT(address _usdt) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "CDOPersonalToken: must have admin role to upgrade"
        );

        usdtToken = _usdt;
    }

    function calculateBuyPrice(uint256 amount) public view returns (uint256) {
        uint256 totalSupply = token.totalSupply();
        uint256 nextTotalSupply = totalSupply.add(amount);
        int128 price = _price(ABDKMath64x64.divu(totalSupply, _DECIMALS), ABDKMath64x64.divu(nextTotalSupply, _DECIMALS));
        return ABDKMath64x64.mulu(price, _DECIMALS);
    }

    function calculateSellPrice(uint256 amount) public view returns (uint256) {
        uint256 totalSupply = token.totalSupply();
        uint256 nextTotalSupply = totalSupply.sub(amount);
        int128 price = _price(ABDKMath64x64.divu(totalSupply, _DECIMALS), ABDKMath64x64.divu(nextTotalSupply, _DECIMALS));
        return ABDKMath64x64.mulu(price, _DECIMALS);
    }

    /**
     * @dev Calculates equation ( x^(1/3)/1000 + y^(1/3)/1000 ) / 2
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

    function _addressIsValid(address _addr) internal pure returns (bool) {
        return _addr != address(0);
    }
}
