# Starkswap AMM Contracts [![Starkswap AMM CI](https://github.com/Starkswap/starkswap-contracts/actions/workflows/CI.yml/badge.svg)](https://github.com/Starkswap/starkswap-contracts/actions/workflows/CI.yml)

Contracts for the Starkswap V1 AMM supporting volatile (`xy = k`) as well as stable (`x^3y * y^3x = k`) curves.

# Development setup
This project uses Scarb as well as hardhat with the starknet-hardhat plugin. This in turn requires docker to be running in the default configuration.

1) Clone the repo
2) Run `yarn install` to get all the required dependencies
3) `yarn build` compiles all the contracts present in the repo
4) `yarn test` runs the test suite

# Toolchain version
```
scarb 2.3.0 (f306f9a91 2023-10-23)
cairo: 2.3.0 (https://crates.io/crates/cairo-lang-compiler/2.3.0)
sierra: 1.3.0
```
