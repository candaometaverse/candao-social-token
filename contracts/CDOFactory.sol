// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./token/CDOPersonalToken.sol";
import "./CDOBondingCurve.sol";

contract CDOFactory is Ownable {
    using Clones for address;

    address public personalTokenImplementation;
    address public personalTokenPoolImplementation;
    address public protocolFeeReceiver;

    string private constant ERROR_ADDRESS = "CDOPersonalToken: invalid address";

    event CreatePersonalToken(
        address indexed personalTokenCreator,
        address indexed personalToken,
        address indexed personalTokenPool
    );

    constructor(
        address personalTokenImplementationAddress,
        address personalTokenPoolImplementationAddress,
        address protocolFeeReceiverAddress
    ) {
        if (!_addressIsValid(personalTokenImplementationAddress))
            revert InvalidAddress();
        if (!_addressIsValid(personalTokenPoolImplementationAddress))
            revert InvalidAddress();
        if (!_addressIsValid(protocolFeeReceiverAddress))
            revert InvalidAddress();

        personalTokenImplementation = personalTokenImplementationAddress;
        personalTokenPoolImplementation = personalTokenPoolImplementationAddress;
        protocolFeeReceiver = protocolFeeReceiverAddress;
    }

    function createPersonalToken(
        string memory name,
        string memory symbol,
        address usdtToken,
        uint256 transactionFee
    ) external {
        if (!_addressIsValid(usdtToken))
            revert InvalidAddress();

        // Create personal token
        address personalToken = personalTokenImplementation.clone();
        CDOPersonalToken(personalToken).initialize(name, symbol);

        // Create personal token pool
        address pool = personalTokenPoolImplementation.clone();
        CDOBondingCurve(pool).initialize(personalToken, protocolFeeReceiver, usdtToken, transactionFee);

        // Enable the pool to mint tokens
        CDOPersonalToken(personalToken).transferOwnership(pool);

        // Transfer ownership of the pool to message sender
        CDOBondingCurve(pool).transferOwnership(_msgSender());

        emit CreatePersonalToken(_msgSender(), address(personalToken), address(pool));
    }

    function setPersonalTokenImplementation(address tokenImplementation) external onlyOwner {
        if (!_addressIsValid(tokenImplementation))
            revert InvalidAddress();

        personalTokenImplementation = tokenImplementation;
    }

    function setPersonalTokenPoolImplementation(address poolImplementation) external onlyOwner {
        if (!_addressIsValid(poolImplementation))
            revert InvalidAddress();

        personalTokenPoolImplementation = poolImplementation;
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
