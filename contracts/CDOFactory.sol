// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CDOBondingCurve.sol";
import "./token/CDOPersonalToken.sol";

contract CDOFactory is Ownable {

    event CreatePersonalToken(
        address indexed personalTokenCreator,
        address indexed personalToken,
        address indexed personalTokenPool
    );

    constructor() {}

    function createPersonalToken(
        string memory name,
        string memory symbol,
        address usdtToken
    ) external {
        // Create personal token
        CDOPersonalToken personalToken = new CDOPersonalToken(name, symbol);

        // Create personal token pool
        CDOBondingCurve pool = new CDOBondingCurve(
            address(personalToken),
            owner(),
            usdtToken
        );

        // Enable the pool to mint tokens
        personalToken.transferOwnership(address(pool));

        // Transfer ownership of the pool to message sender
        pool.transferOwnership(_msgSender());

        emit CreatePersonalToken(_msgSender(), address(personalToken), address(pool));
    }
}
