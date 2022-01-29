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
    bytes32 public constant OPEN_ROLE =
        0xefa06053e2ca99a43c97c4a4f3d8a394ee3323a8ff237e625fba09fe30ceb0a4;

    uint256 public constant INITIAL_SUPPLY = 10000 * 10**18; // 10 000 CDO
    uint8 public constant PCT_BASE = 100;
    uint8 public constant FEE_BASE = 25;
    uint8 public constant MC_AGGREGATION = 23;
    uint8 public constant PT_BASE = 1;
    uint8 public constant PROTOCOL_BASE = 1;

    string private constant ERROR_ADDRESS = "MM_ADDRESS_IS_EOA";
    string private constant ERROR_NOT_OPEN = "MM_NOT_OPEN";
    string private constant ERROR_NOT_DEPOSIT = "MM_DEPOSIT_USDT_ERROR";
    string private constant ERROR_NOT_WITHDRAW = "MM_WITHDRAW_USDT_ERROR";
    string private constant ERROR_NOT_ENOUGH_USDT =
        "MM_INSUFFICIENT_USDT_ERROR";
    string private constant ERROR_NOT_ENOUGH_ALLOWANCE =
        "MM_INSUFFICIENT_ALLOWANCE";

    CDOPersonalToken public token;
    address public PT_treasury;
    address public Protocol_treasury;
    address public usdt_token;

    bool public isOpen;
    uint256 public marketCap;
    uint256 public currentPrice;
    uint256 public ptTreasuryAmount;
    uint256 public protocolTreasuryAmount;

    event Open(bool indexed status);
    event BuyPT(
        address indexed buyer,
        uint256 indexed buyAmount,
        uint256 indexed buyPrice
    );
    event SellPT(
        address indexed seller,
        uint256 indexed sellAmount,
        uint256 indexed sellPrice
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
        marketCap = _depositAmount.add(
            _calculateFee(_depositAmount).mul(uint256(MC_AGGREGATION)).div(
                uint256(FEE_BASE)
            )
        );
        ptTreasuryAmount = _calculateBuyPT(_depositAmount);
        protocolTreasuryAmount = _calculateBuyProtocol(_depositAmount);
        currentPrice = marketCap.div(INITIAL_SUPPLY);
        ERC20(usdt_token).safeTransfer(address(this), _depositAmount);
        ERC20(usdt_token).safeTransfer(PT_treasury, ptTreasuryAmount);
        ERC20(usdt_token).safeTransfer(
            Protocol_treasury,
            protocolTreasuryAmount
        );
        isOpen = true;
    }

    function buy(uint256 _buyAmount) external nonReentrant {
        require(isOpen, ERROR_NOT_OPEN);
        uint256 _depositAmount = currentPrice.mul(_buyAmount);
        uint256 _PTAmount = _calculateBuyPT(_depositAmount);
        uint256 _ProtocolAmount = _calculateBuyProtocol(_depositAmount);
        require(
            ERC20(usdt_token).balanceOf(_msgSender()) >=
                _depositAmount.add(_calculateFee(_depositAmount)),
            ERROR_NOT_ENOUGH_USDT
        );
        require(
            ERC20(usdt_token).allowance(_msgSender(), address(this)) >=
                _depositAmount.add(_calculateFee(_depositAmount)),
            ERROR_NOT_ENOUGH_ALLOWANCE
        );

        ERC20(usdt_token).safeTransferFrom(_msgSender(), address(this), _depositAmount);
        ERC20(usdt_token).safeTransferFrom(_msgSender(), PT_treasury, _PTAmount);
        ERC20(usdt_token).safeTransferFrom(_msgSender(), Protocol_treasury, _ProtocolAmount);
        token.mint(_msgSender(), _buyAmount);
        emit BuyPT(_msgSender(), _buyAmount, currentPrice);
        marketCap = marketCap.add(_calculateMC(_depositAmount));
        ptTreasuryAmount = ptTreasuryAmount.add(_PTAmount);
        protocolTreasuryAmount = protocolTreasuryAmount.add(_ProtocolAmount);
        currentPrice = marketCap.div(token.totalSupply());
    }

    function sell(uint256 _sellAmount) external nonReentrant {
        require(isOpen, ERROR_NOT_OPEN);
        uint256 _withdrawAmount = currentPrice.mul(_sellAmount);
        uint256 _PTAmount = _calculateSellPT(_withdrawAmount);
        uint256 _ProtocolAmount = _calculateSellProtocol(_withdrawAmount);

        token.burnFrom(_msgSender(), _sellAmount);
        ERC20(usdt_token).safeIncreaseAllowance(_msgSender(), _withdrawAmount);
        ERC20(usdt_token).safeTransferFrom(address(this), _msgSender(), _withdrawAmount);
        ERC20(usdt_token).safeIncreaseAllowance(PT_treasury, _PTAmount);
        ERC20(usdt_token).safeTransferFrom(address(this), PT_treasury, _PTAmount);
        ERC20(usdt_token).safeIncreaseAllowance(Protocol_treasury, _ProtocolAmount);
        ERC20(usdt_token).safeTransferFrom(address(this), Protocol_treasury, _ProtocolAmount);
        emit SellPT(_msgSender(), _sellAmount, currentPrice);
        marketCap = marketCap.sub(_calculateMC(_withdrawAmount));
        ptTreasuryAmount = ptTreasuryAmount.add(_PTAmount);
        protocolTreasuryAmount = protocolTreasuryAmount.add(_ProtocolAmount);
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

    function _calculateFee(uint256 _Amount) internal pure returns (uint256) {
        return _Amount.mul(uint256(FEE_BASE)).div(uint256(PCT_BASE));
    }

    function _calculateBuyPT(uint256 _depositAmount)
        internal
        pure
        returns (uint256)
    {
        return
            _calculateFee(_depositAmount).mul(uint256(PT_BASE)).div(
                uint256(MC_AGGREGATION).add(uint256(PT_BASE)).add(
                    uint256(PROTOCOL_BASE)
                )
            );
    }

    function _calculateBuyProtocol(uint256 _depositAmount)
        internal
        pure
        returns (uint256)
    {
        return
            _calculateFee(_depositAmount).mul(uint256(PROTOCOL_BASE)).div(
                uint256(MC_AGGREGATION).add(uint256(PT_BASE)).add(
                    uint256(PROTOCOL_BASE)
                )
            );
    }

    function _calculateSellPT(uint256 _withdrawAmount)
        internal
        pure
        returns (uint256)
    {
        return
            _calculateFee(_withdrawAmount).mul(uint256(PT_BASE)).div(
                uint256(PT_BASE).add(uint256(PROTOCOL_BASE))
            );
    }

    function _calculateSellProtocol(uint256 _withdrawAmount)
        internal
        pure
        returns (uint256)
    {
        return
            _calculateFee(_withdrawAmount).mul(uint256(PROTOCOL_BASE)).div(
                uint256(PT_BASE).add(uint256(PROTOCOL_BASE))
            );
    }

    function _calculateMC(uint256 _Amount) internal pure returns (uint256) {
        return
            _Amount.add(
                _calculateFee(_Amount).mul(uint256(MC_AGGREGATION)).div(
                    uint256(MC_AGGREGATION).add(uint256(PT_BASE)).add(
                        uint256(PROTOCOL_BASE)
                    )
                )
            );
    }
}
