# Candao social token

Factory contract was deployed to Mumbai polygon network.

```
CDOFactory address: 0xA52FE21a269a6aa1b78876F79C62Bd010966fF9c
```

## How use factory ?

1. Browse polygon scan with contract argument
https://mumbai.polygonscan.com/address/0xA52FE21a269a6aa1b78876F79C62Bd010966fF9c#code

2. Create social token
It will create social token contract and bounding curve pool. The curve pool is not activated.
The transaction fee value is in 0.01% units, so 100 = 1%.

```
function createSocialToken(string memory name, string memory symbol, uint256 transactionFee) external
```

3. Activate the pool

The marketing budget value is in 0.01% units, so 100 = 1%.
The marketing budget goes directly to marketing pool address, which is defined during factory initialization.

```
function activate(address usdtTokenAddress, uint256 amountToBuy, uint256 marketingBudgetValue) external onlyOwner()
```

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
