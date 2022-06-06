# Candao social token

Factory contract was deployed to Mumbai polygon network.

```
CDOFactory address: 0xDa2506c12ba0d9fbAfF7EA2bbf6C04BA772f43E3
```

## How use factory ?

1. Browse polygon scan with contract argument
https://mumbai.polygonscan.com/address/0xDa2506c12ba0d9fbAfF7EA2bbf6C04BA772f43E3#code

2. Create social token
It will create social token contract and bounding curve pool

3. Activate the pool

4. Buy or Sell tokens

## Commands

```shell
# compile all contracts
npx hardhat compile

# clean build
npx hardhat clean

# execute unit tests
npx hardhat test

# deploy factory contract
npx hardhat run scripts/deploy.js --network localhost
```

## CDOBondingCurve Contract Interface

### Buy
When the user wants to buy CDOPT, user should call this function.
When someone buy CDOPT, the token price would be changed on CDO BondingCurve Price model

```
function buy(uint256 amount) external
```

### Sell
When the user wants to sell CDOPT, user should call this function.
When someone sell CDOPT, the token price would be changed on CDO BondingCurve Price model

```
function sell(uint256 amount) external
```
