// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./token/v1/CDOPersonalToken.sol";

contract CDOBondingCurve is AccessControl, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using SafeERC20 for CDOPersonalToken;
    using SafeMath for uint256;

    /**
    Hardcoded constants to save gas
    bytes32 public constant OPEN_ROLE                    = keccak256("OPEN_ROLE");
    */
    bytes32 public constant OPEN_ROLE                    = 0xefa06053e2ca99a43c97c4a4f3d8a394ee3323a8ff237e625fba09fe30ceb0a4;

    uint256 public constant INITIAL_SUPPLY          = 10000 * 10 ** 18; // 10 000 CDO
    uint8   public constant PCT_BASE                = 100;
    uint8   public constant FEE_BASE                = 25;
    uint8   public constant MC_AGGREGATION          = 23;
    uint8   public constant PT_BASE                 = 1;
    uint8   public constant PROTOCOL_BASE           = 1;

    string private constant ERROR_ADDRESS                           = "MM_ADDRESS_IS_EOA";
    string private constant ERROR_NOT_OPEN                          = "MM_NOT_OPEN";
    string private constant ERROR_NOT_DEPOSIT                       = "MM_DEPOSIT_USDT_ERROR";

    CDOPersonalToken                public token;
    address                         public PT_treasury;
    address                         public Protocol_treasury;
    address                         public usdt_token;

    bool                            public isOpen;
    uint256                         public marketCap;
    uint256                         public currentPrice;
    uint256                         public ptTreasuryAmount;
    uint256                         public protocolTreasuryAmount;

    event Open                      (bool indexed status);
    event BuyPT                     (address indexed buyer, uint256 indexed buyAmount, uint256 indexed buyPrice);
    event SellPT                    (address indexed seller, uint256 indexed sellAmount, uint256 indexed sellPrice);

    /**
     * @notice Initialize market maker
     * @param _token The address of CDOPersonalToken contract
     * @param _ptTreasury The address of 
     */
    constructor(
        address         _token,
        address         _ptTreasury,
        address         _protocolTreasury,
        address         _usdtToken
    )
    {
        require(_addressIsValid(_ptTreasury),           ERROR_ADDRESS);
        require(_addressIsValid(_protocolTreasury),     ERROR_ADDRESS);
        require(_addressIsValid(_usdtToken),            ERROR_ADDRESS);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        token = CDOPersonalToken(_token);
        PT_treasury = _ptTreasury;
        Protocol_treasury = _protocolTreasury;
        usdt_token = _usdtToken;
    }

    function activate(address _treasury, uint256 _depositAmount) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "CDOPersonalToken: must have admin role to activate"
        );
        token.activate(_treasury, INITIAL_SUPPLY);
        marketCap = _depositAmount.add(_calculateFee(_depositAmount).mul(uint256(MC_AGGREGATION)).div(uint256(FEE_BASE)));
        currentPrice = marketCap.div(INITIAL_SUPPLY);
        ERC20(usdt_token).transfer(address(this), _depositAmount);
        isOpen = true;
    }

    function buy(uint256 _buyAmount) external {
        require(isOpen, ERROR_NOT_OPEN);
        uint256 _depositAmount = currentPrice.mul(_buyAmount);
        require(ERC20(usdt_token).transfer(address(this), _depositAmount), ERROR_NOT_DEPOSIT);
        token.mint(_msgSender(), _buyAmount);
        emit BuyPT(_msgSender(), _buyAmount, currentPrice);
        marketCap = marketCap.add(_calculateBuyMC(_depositAmount));
        currentPrice = marketCap.div(token.totalSupply());
    }

    /**
     * @notice Open market making [enabling users to open buy and sell orders]
    */
    function open(bool _status) external onlyRole(OPEN_ROLE) {
        _open(_status);
    }

    /* state modifiying functions */

    function _open(bool _status) internal {
        isOpen = _status;

        emit Open(_status);
    }

    function _addressIsValid(address _addr) internal pure returns (bool) {
        return _addr != address(0);
    }

    function _calculateFee(uint256 _depositAmount) internal pure returns (uint256) {
        return _depositAmount.mul(uint256(FEE_BASE)).div(uint256(PCT_BASE));
    }

    function _calculatePT(uint256 _depositAmount) internal pure returns (uint256) {
        return _depositAmount.mul(uint256(PT_BASE)).div(uint256(PCT_BASE));
    }

    function _calculateProtocol(uint256 _depositAmount) internal pure returns (uint256) {
        return _depositAmount.mul(uint256(PROTOCOL_BASE)).div(uint256(PCT_BASE));
    }

    function _calculateBuyMC(uint256 _depositAmount) internal pure returns (uint256) {
        return _depositAmount.add(_calculateFee(_depositAmount).mul(uint256(MC_AGGREGATION)).div(uint256(FEE_BASE)));
    }

}