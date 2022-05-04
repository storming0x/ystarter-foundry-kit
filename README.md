# Yearn Starter Kit

**All code in this repository is meant for instructional purposes only. Is not audited or considered safe for production.**

## What you'll find here

- Basic example Solidity Smart Contracts for integrating with Yearn Vaults. Both V2 and ERC4626 interfaces.

- ERC4626 adapter to wrap yearn vaults.

- Sample test suite. ([`tests`](src/test/))

### Yearn Vault ->  ERC4626  Adapter

([`contracts/VaultWrapper.sol`](contracts/VaultWrapper.sol))

VaultWrapper is an ERC4626 router interface that makes v2 vaults compatible with the standard. A router/wrapper is needed per deployed vault. Contracts can interact with the router as they would with any ERC4626 since it adapts almost all the methods seamlessly.

NOTE: This adapter makes vault operations more gas expensive since its 
doing additional calls to normal vault methods like deposit/operations to wrap the vault tokens into the 4626 interface adapter.

Given the flexibility, the gas increase tradeoff may be good for integrators using multiple 4626 to keep code cohesive for all yield sources.


## Installation and Setup

1. To install with [Foundry](https://github.com/gakonst/foundry).

2. Fork this repository.

3. Clone your newly created repository recursively to include modules.

```sh
git clone --recursive https://github.com/storming0x/ystarter-foundry-kit.git

cd ystarter-foundry-kit
```

NOTE: if you create from template you may need to run the following command to fetch the git submodules (.gitmodules for exact releases) `git submodule init && git submodule update`

4. Build the project.

```sh
make build
```

5. Sign up for [Infura](https://infura.io/) and generate an API key and copy your RPC url. Store it in the `ETH_RPC_URL` environment variable.
NOTE: you can use other services.

6. Use .env file
  1. Make a copy of `.env.example`
  2. Add the values for `ETH_RPC_URL`, `ETHERSCAN_API_KEY` and other example vars
     NOTE: If you set up a global environment variable, that will take precedence.

7. Run tests
```sh
make test
```

## Basic Use

To deploy the demo Yearn Vaults and ERC4626 adapter in a development environment:

TODO

## Testing

Tests run in fork environment, you need to complete [Installation and Setup](#installation-and-setup) step 6 to be able to run these commands.

```sh
make test
```
Run tests with traces (very useful)

```sh
make trace
```
Run specific test contract (e.g. `test/MyTest.t.sol`)

```sh
make test-contract contract=MyTest
```
Run specific test contract with traces (e.g. `test/MyTest.t.sol`)

```sh
make trace-contract contract=MyTest
```

See here for some tips on testing [`Testing Tips`](https://book.getfoundry.sh/forge/tests.html)

# Resources

- Yearn [Discord channel](https://discord.com/invite/6PNv2nF/)
- [Getting help on Foundry](https://github.com/gakonst/foundry#getting-help)
- [Forge Standard Lib](https://github.com/brockelmore/forge-std)
- [Awesome Foundry](https://github.com/crisgarner/awesome-foundry)
- [Foundry Book](https://book.getfoundry.sh/)
- [Learn Foundry Tutorial](https://www.youtube.com/watch?v=Rp_V7bYiTCM)

