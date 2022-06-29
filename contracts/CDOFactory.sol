// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./token/CDOSocialToken.sol";
import "./CDOBondingCurve.sol";

contract CDOFactory is Ownable {
    using Clones for address;

    address public socialTokenImplementation;
    address public socialTokenPoolImplementation;
    address public protocolFeeReceiver;
    address public marketingPool;
    // marketing budget is in 0.01% units so 100 = 1%
    uint256 public minMarketingBudget;

    string private constant ERROR_ADDRESS = "invalid address";

    event CreateSocialToken(
        address indexed socialTokenCreator,
        address indexed socialToken,
        address indexed socialTokenPool
    );

    constructor(
        address socialTokenImplementationAddress,
        address socialTokenPoolImplementationAddress,
        address protocolFeeReceiverAddress,
        address marketingPoolAddress,
        uint256 minMarketingBudgetValue
    ) {
        if (!_addressIsValid(socialTokenImplementationAddress))
            revert InvalidAddress();
        if (!_addressIsValid(socialTokenPoolImplementationAddress))
            revert InvalidAddress();
        if (!_addressIsValid(protocolFeeReceiverAddress))
            revert InvalidAddress();
        if (!_addressIsValid(marketingPoolAddress))
            revert InvalidAddress();
        if (minMarketingBudgetValue > 10000)
            revert InvalidMinimumMarketingBudgetValue();

        socialTokenImplementation = socialTokenImplementationAddress;
        socialTokenPoolImplementation = socialTokenPoolImplementationAddress;
        protocolFeeReceiver = protocolFeeReceiverAddress;
        marketingPool = marketingPoolAddress;
        minMarketingBudget = minMarketingBudgetValue;
    }

    function createSocialToken(
        string memory name,
        string memory symbol,
        uint256 transactionFee
    ) external {

        // Create social token
        address socialToken = socialTokenImplementation.clone();
        CDOSocialToken(socialToken).initialize(name, symbol);

        // Create social token pool
        address pool = socialTokenPoolImplementation.clone();
        CDOBondingCurve(pool).initialize(
            socialToken, protocolFeeReceiver, transactionFee, marketingPool, minMarketingBudget);

        // Enable the pool to mint tokens
        CDOSocialToken(socialToken).transferOwnership(pool);

        // Transfer ownership of the pool to message sender
        CDOBondingCurve(pool).transferOwnership(_msgSender());

        emit CreateSocialToken(_msgSender(), address(socialToken), address(pool));
    }

    function setSocialTokenImplementation(address tokenImplementation) external onlyOwner {
        if (!_addressIsValid(tokenImplementation))
            revert InvalidAddress();

        socialTokenImplementation = tokenImplementation;
    }

    function setSocialTokenPoolImplementation(address poolImplementation) external onlyOwner {
        if (!_addressIsValid(poolImplementation))
            revert InvalidAddress();

        socialTokenPoolImplementation = poolImplementation;
    }

    function setProtocolFeeReceiver(address feeReceiver) external onlyOwner {
        if (!_addressIsValid(feeReceiver))
            revert InvalidAddress();

        protocolFeeReceiver = feeReceiver;
    }

    function setMarketingPool(address marketingPoolAddress) external onlyOwner {
        if (!_addressIsValid(marketingPoolAddress))
            revert InvalidAddress();

        marketingPool = marketingPoolAddress;
    }

    function setMinMarketingBudget(uint256 minMarketingBudgetValue) external onlyOwner {
        if (minMarketingBudgetValue > 10000)
            revert InvalidMinimumMarketingBudgetValue();

        minMarketingBudget = minMarketingBudgetValue;
    }

    /**
     * @dev Checks if address is not empty
     */
    function _addressIsValid(address _addr) internal pure returns (bool) {
        return _addr != address(0);
    }
}
