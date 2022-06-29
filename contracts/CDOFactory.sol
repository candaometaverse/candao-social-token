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

    string private constant ERROR_ADDRESS = "invalid address";

    event CreateSocialToken(
        address indexed socialTokenCreator,
        address indexed socialToken,
        address indexed socialTokenPool
    );

    constructor(
        address socialTokenImplementationAddress,
        address socialTokenPoolImplementationAddress,
        address protocolFeeReceiverAddress
    ) {
        if (!_addressIsValid(socialTokenImplementationAddress))
            revert InvalidAddress();
        if (!_addressIsValid(socialTokenPoolImplementationAddress))
            revert InvalidAddress();
        if (!_addressIsValid(protocolFeeReceiverAddress))
            revert InvalidAddress();

        socialTokenImplementation = socialTokenImplementationAddress;
        socialTokenPoolImplementation = socialTokenPoolImplementationAddress;
        protocolFeeReceiver = protocolFeeReceiverAddress;
    }

    function createSocialToken(
        string memory name,
        string memory symbol,
//        address usdtToken,
        uint256 transactionFee
    ) external {
//        if (!_addressIsValid(usdtToken))
//            revert InvalidAddress();

        // Create social token
        address socialToken = socialTokenImplementation.clone();
        CDOSocialToken(socialToken).initialize(name, symbol);

        // Create social token pool
        address pool = socialTokenPoolImplementation.clone();
        CDOBondingCurve(pool).initialize(socialToken, protocolFeeReceiver, transactionFee);

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

    /**
     * @dev Checks if address is not empty
     */
    function _addressIsValid(address _addr) internal pure returns (bool) {
        return _addr != address(0);
    }
}
