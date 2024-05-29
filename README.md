## NFT backed ERC20 token

### Contracts

#### NFTBackedToken.sol

An upgradeable ERC20 token which is backed by NFTs.
Depositing NFTs into the contract mints ERC20 tokens.
Redeeming the NFTs is possible by burning the ERC20 tokens.

A fixed conversion rate is configured when initializing the contract.

#### TokenDeployer.sol

A factory for deploying NFTBackedTokens.

### Deployment

```
forge build
forge create TokenDeployer --verify --rpc-url $RPC_SEPOLIA -i

# verify contracts if needed
forge verify-contract ...
```

| Chain   | Contract      | Address                                                                                                                       |
| ------- | ------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Sepolia | TokenDeployer | [0x3Ee7C7eaa83aBDf28F0aFca4a19fEf4613825B3C](https://sepolia.etherscan.io/address/0x3Ee7C7eaa83aBDf28F0aFca4a19fEf4613825B3C) |
