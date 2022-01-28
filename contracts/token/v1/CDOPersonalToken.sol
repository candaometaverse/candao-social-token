// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev {ERC20} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract CDOPersonalToken is Initializable, ERC20PresetMinterPauserUpgradeable {
    /**
     * @dev Initialize token name as `name` & symbol as `symbol`
     *
     * {ERC20PresetMinterPauserUpgradeable - __ERC20PresetMinterPauser_init}
     *
     * Requirements:
     *
     * - the caller would be owner of token
     *
     * - make sure the caller as admin to have `DEFAULT_ADMIN_ROLE`
     */
    function initialize(string memory name, string memory symbol)
        public
        override
        initializer
    {
        __ERC20PresetMinterPauser_init(name, symbol);
        _pause();
    }

    /**
     * @dev Setup `initialSupply` new tokesn to `treasury`
     *
     * See {ERC20-_mint}
     *
     * Requirements:
     *
     * - the caller must have the `DEFAULT_ADMIN_ROLE`.
     */
    function activate(address treasury, uint256 initialSupply) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "CDOPersonalToken: must have admin role to activate"
        );
        _mint(treasury, initialSupply);
        unpause();
    }
}
