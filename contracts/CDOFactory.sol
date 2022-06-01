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

    event CreatePersonalToken(
        address indexed personalTokenCreator,
        address indexed personalToken,
        address indexed personalTokenPool
    );

    constructor(address personalTokenImplementationAddress, address personalTokenPoolImplementationAddress) {
        personalTokenImplementation = personalTokenImplementationAddress;
        personalTokenPoolImplementation = personalTokenPoolImplementationAddress;
    }

    function createPersonalToken(
        string memory name,
        string memory symbol,
        address usdtToken,
        uint256 transactionFee
    ) external {
        // Create personal token
        address personalToken = personalTokenImplementation.clone();
        CDOPersonalToken(personalToken).initialize(name, symbol);

        // Create personal token pool
        address pool = personalTokenPoolImplementation.clone();
        CDOBondingCurve(pool).initialize(personalToken, owner(), usdtToken, transactionFee);

        // Enable the pool to mint tokens
        CDOPersonalToken(personalToken).transferOwnership(pool);

        // Transfer ownership of the pool to message sender
        CDOBondingCurve(pool).transferOwnership(_msgSender());

        emit CreatePersonalToken(_msgSender(), address(personalToken), address(pool));
    }

    function setPersonalTokenImplementation(address tokenImplementation) onlyOwner external {
        require(tokenImplementation != address(0), "CDOFactory: invalid address");

        personalTokenImplementation = tokenImplementation;
    }

    function setPersonalTokenPoolImplementation(address poolImplementation) onlyOwner external {
        require(poolImplementation != address(0), "CDOFactory: invalid address");

        personalTokenPoolImplementation = poolImplementation;
    }
}
