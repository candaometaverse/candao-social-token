# Basic Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts.

Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
node scripts/sample-script.js
npx hardhat help
```
``` Mumbai Testnet Deployments
CDOPersonalToken Deployed to: 0x99e4a470532a69b1De4EE35C0586202a7596160F
CDOBondingCurve Deployed to: 0xB674D7072D0128D855833732722cfC677852dFD5
```

``` CDO Bonding Curve Overview
First of all, deploy CDOPersonal Token to the network.(Using Openzeppelin deployProxy)

As a second, deploy CDOBondingCurve with specific parameters
CDOPersonalToken Address, PT Treasury Address, ProtocolTreasury Address, USDT Token address

After CDOBondingCurve SC is deployed, in CDOPersonalToken, set up CDOBondingCurve SC as `ACTIVATION_ROLE` with default admin role
On the other hands, call `Activate` function in CDOBondingCurve with default admin role in BondingCurve.

## CDOBondingCurve Contract Interface

### 1. Buy
When the user wants to buy CDOPT, user should call this function.
When someone buy CDOPT, the token price would be changed on CDO BondingCurve Price model

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

###2. sell
When the user wants to sell CDOPT, user should call this function.
When someone sell CDOPT, the token price would be changed on CDO BondingCurve Price model

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
```