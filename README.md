# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
GAS_REPORT=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

## Deploy

npx hardhat run --network testnet ./scripts/deploy.ts

## BSC Testnet

PancakeFactory: `0x6725F303b657a9451d8BA641348b6761A6CC7a17`

PancakeRouter: `0xD99D1c33F9fC3444f8101754aBC46c52416550D1`

WBNB: `0xBdf1a2e17DECb2aAC725F0A1C8C4E2205E70719C`

## BSC Mainnet

PancakeFactory: `0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73`

PancakeRouter: `0x10ED43C718714eb63d5aA57B78B54704E256024E`

WBNB: `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c`

## Remove Liquidity Steps

1. Disable swapAndLiquify with "updateSwapAndLiquifyEnabled" function and set false value, otherwise it will fails
2. Remove liquidity
3. Some of the contract tokens will transfer to the contract as tax fee. Use "withdrawTaxFees" to transfer them to the taxReceiver address.
