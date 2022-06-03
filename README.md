# Candao personal token

Factory contract was deployed to Mumbai polygon network.

```
CDOFactory address: 0x1e2393a4F760385D79f362d7D8a09562937a72FB
```

## How use factory ?

1. Browse polygon scan with contract argument
https://mumbai.polygonscan.com/address/0x1e2393a4F760385D79f362d7D8a09562937a72FB#code
2. Create personal token
It will create personal token contract and bounding curve pool
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
function buy(uint256 _buyAmount) external
```

### Sell
When the user wants to sell CDOPT, user should call this function.
When someone sell CDOPT, the token price would be changed on CDO BondingCurve Price model

```
function sell(uint256 _sellAmount) external
```
