// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract CDOSocialToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable
{
    uint256 public constant INITIAL_SUPPLY = 10 ** 18;

    function initialize(string memory name, string memory symbol)
        public
        initializer
    {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __Ownable_init();

        _mint(address(this), INITIAL_SUPPLY);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
