# <h1 align="center"> Charity Vaults </h1>

Share interest from Fuse Vaults with charities, friends, and more.

<div align="center">

![Lints](https://github.com/Rari-Capital/charity-vaults/workflows/Linting/badge.svg)
![Tests](https://github.com/Rari-Capital/charity-vaults/workflows/Tests/badge.svg)

</div>

### Getting Started

```sh
git clone https://github.com/Rari-Capital/charity-vaults.git
cd charity-vaults
make
make test
```

### Credits

-   [t11s](https://twitter.com/transmissions11), [Jet Jadeja](https://twitter.com/JetJadeja), and [David Lucid](https://twitter.com/davidlucid) for the exceptional guidance and contributions.
-   [Georgios Konstantopoulos](https://github.com/gakonst) for the amazing [dapptools-template](https://github.com/gakonst/dapptools-template) resource.

### Generate Pretty Visuals

We use [surya](https://github.com/ConsenSys/surya) to create contract diagrams.

Run `npm run visualize` to generate an amalgamated contract visualization in the `./assets/` directory. Or use the below commands for each respective contract.

##### CharityVault.sol

Run `surya graph src/CharityVault.sol | dot -Tpng > assets/CharityVault.png`

#### CharityVaultFactory.sol

Run `surya graph src/CharityVaultFactory.sol | dot -Tpng > assets/CharityVaultFactory.png`

## Deploying

Contracts can be deployed via the `make deploy` command. Addresses are automatically
written in a name-address json file stored under `out/addresses.json`.

We recommend testing your deployments and provide an example under [`scripts/test-deploy.sh`](./scripts/test-deploy.sh)
which will launch a local testnet, deploy the contracts, and do some sanity checks.

Environment variables under the `.env` file are automatically loaded (see [`.env.example`](./.env.example)).
Be careful of the [precedence in which env vars are read](https://github.com/dapphub/dapptools/tree/2cf441052489625f8635bc69eb4842f0124f08e4/src/dapp#precedence).

We assume `ETH_FROM` is an address you own and is part of your keystore.
If not, use `ethsign import` to import your private key.

See the [`Makefile`](./Makefile#25) for more context on how this works under the hood

We use Alchemy as a remote node provider for the Mainnet & Rinkeby network deployments.
You must have set your API key as the `ALCHEMY_API_KEY` enviroment variable in order to
deploy to these networks

### Mainnet

```
ETH_FROM=0x3538b6eF447f244268BCb2A0E1796fEE7c45002D make deploy-mainnet
```

### Rinkeby

```
ETH_FROM=0x3538b6eF447f244268BCb2A0E1796fEE7c45002D make deploy-rinkeby
```

### Goerli

To deploy, the contracts have to be built by running the `dapp build` command.

#### TrustAuthority

TrustAuthority was deployed to `0xef619040fc0ff9a21b42fabe031af716610df0d7` on [Goerli](https://goerli.etherscan.io/address/0xef619040fc0ff9a21b42fabe031af716610df0d7) using the following command in the [solmate](./lib/solmate) subdir:

```sh
ETH_FROM=xxxx ETH_RPC_URL=xxxx ETH_GAS=xxxx dapp create src/auth/authorities/TrustAuthority.sol:TrustAuthority <ETH_FROM> --verify
```

Then verified with:

```sh
ETH_FROM=xxxx ETH_RPC_URL=xxxx ETH_GAS=xxxx dapp verify-contract src/auth/authorities/TrustAuthority.sol:TrustAuthority 0xef619040fc0ff9a21b42fabe031af716610df0d7 <ETH_FROM>
```

#### VaultFactory

VaultFactory was deployed to `0x57d0721bb6021e821ab98925007534aed16ecb12` on [Goerli](https://goerli.etherscan.io/address/0x57d0721bb6021e821ab98925007534aed16ecb12) using the following command in the [vaults](./lib/vaults) subdir:

```sh
ETH_FROM=xxxx ETH_RPC_URL=xxxx ETH_GAS=xxxx dapp create src/VaultFactory.sol:VaultFactory <ETH_FROM> 0xeF619040fC0ff9A21B42fAbe031aF716610Df0D7 --verify
```

Then verified with:

```
ETH_FROM=xxxx ETH_RPC_URL=xxxx ETH_GAS=xxxx dapp verify-contract ./src/VaultFactory.sol:VaultFactory 0x57d0721bb6021e821ab98925007534aed16ecb12 <ETH_FROM> 0xeF619040fC0ff9A21B42fAbe031aF716610Df0D7
```

Set the Authority on the VaultFactory with the `setAuthority` function and the `TrustAuthority` address: [`0xeF619040fC0ff9A21B42fAbe031aF716610Df0D7`](https://goerli.etherscan.io/address/0xeF619040fC0ff9A21B42fAbe031aF716610Df0D7)


#### Vault

Used Goerli Fake USD: [0xb983C7a6f63623743CeB2F485118a37C9f77d2a0](https://goerli.etherscan.io/address/0xb983C7a6f63623743CeB2F485118a37C9f77d2a0)

Vault was deployed to [`0x05F119002D5520B9cE6d62DA89AE5B23020B5d89`](https://goerli.etherscan.io/address/0x05F119002D5520B9cE6d62DA89AE5B23020B5d89) using the `deployVault` permissionless function in the `VaultFactory` (above).

Since we can't pass the `--verify` flag, we have to verify the Vault contract using dapptools `verify-contract` command as such.

```
ETH_FROM=xxxx ETH_RPC_URL=xxxx ETH_GAS=xxxx dapp verify-contract src/Vault.sol:Vault 0x05F119002D5520B9cE6d62DA89AE5B23020B5d89 0xb983C7a6f63623743CeB2F485118a37C9f77d2a0
```

NOTE: we have to pass in the address of the Fake USD (0xb983C7a6f63623743CeB2F485118a37C9f77d2a0) since it is an argument in the Vault constructor

Set the Authority on the VaultFactory with the `setAuthority` function and the `TrustAuthority` address: [`0xeF619040fC0ff9A21B42fAbe031aF716610Df0D7`](https://goerli.etherscan.io/address/0xeF619040fC0ff9A21B42fAbe031aF716610Df0D7)

#### CharityVaultFactory

Deployed & Verified Charity Vault Factory [`0x8c50a6a21be7375026d0412be3b2c933e2055bcc`](https://goerli.etherscan.io/address/0x8c50a6a21be7375026d0412be3b2c933e2055bcc): `0x8c50a6a21be7375026d0412be3b2c933e2055bcc`

```sh
ETH_FROM=xxxx ETH_RPC_URL=xxxx ETH_GAS=xxxx dapp create src/CharityVaultFactory.sol:CharityVaultFactory 0x57d0721bb6021e821ab98925007534aed16ecb12 --verify
```

Verified With:

```sh
ETH_FROM=xxxx ETH_RPC_URL=xxxx ETH_GAS=xxxx dapp verify-contract src/CharityVaultFactory.sol:CharityVaultFactory 0x8c50a6a21be7375026d0412be3b2c933e2055bcc 0x57d0721bb6021e821ab98925007534aed16ecb12 --verify
```

Set the Authority on the VaultFactory with the `setAuthority` function and the `TrustAuthority` address: [`0xeF619040fC0ff9A21B42fAbe031aF716610Df0D7`](https://goerli.etherscan.io/address/0xeF619040fC0ff9A21B42fAbe031aF716610Df0D7)

#### CharityVault

Used Goerli Fake USD: [0xb983C7a6f63623743CeB2F485118a37C9f77d2a0](https://goerli.etherscan.io/address/0xb983C7a6f63623743CeB2F485118a37C9f77d2a0)

Using the `deployCharityVault` function we can then deploy a CharityVault with the parameters:

-   _underlying_: `0xb983C7a6f63623743CeB2F485118a37C9f77d2a0` (USDC)
-   _charity_: `0x05AB381A007A90E541433f3DC574AcD3E389f898` (random address interest is sent to)
-   _feePercent_: `5` (fee percent - 5%)

Deployed & Verified Charity Vault [0x3Ad5B46BA68A0F4F81fA584ffb15EEaA1A2aE788](https://goerli.etherscan.io/address/0x3Ad5B46BA68A0F4F81fA584ffb15EEaA1A2aE788)

To verify the CharityVault, we run the command:

```sh
ETH_FROM=xxxx ETH_RPC_URL=xxxx ETH_GAS=xxxx dapp verify-contract src/CharityVault.sol:CharityVault 0x3Ad5B46BA68A0F4F81fA584ffb15EEaA1A2aE788 0xb983C7a6f63623743CeB2F485118a37C9f77d2a0 0x05AB381A007A90E541433f3DC574AcD3E389f898 5 0x05F119002D5520B9cE6d62DA89AE5B23020B5d89
```

Where the synatx is:

```
dapp verify-contract src/CharityVault.sol:CharityVault <deployed charity vault address> <underlying token address (USDC)> <charity address> <fee percent> <deployed vault address>
```

Set the Authority on the VaultFactory with the `setAuthority` function and the `TrustAuthority` address: [`0xeF619040fC0ff9A21B42fAbe031aF716610Df0D7`](https://goerli.etherscan.io/address/0xeF619040fC0ff9A21B42fAbe031aF716610Df0D7)

#### Mock CharityVaultStrategy

Used Goerli Fake USD: [0xb983C7a6f63623743CeB2F485118a37C9f77d2a0](https://goerli.etherscan.io/address/0xb983C7a6f63623743CeB2F485118a37C9f77d2a0)

Deployed CharityVaultStrategy at [0xfc2004ee942c2483ce5efac20ca8f9ee6c838790](https://goerli.etherscan.io/address/0xfc2004ee942c2483ce5efac20ca8f9ee6c838790)

Deployed with:

```sh
ETH_FROM=xxxx ETH_RPC_URL=xxxx ETH_GAS=xxxx dapp create src/tests/mocks/CharityVaultMockStrategy.sol:CharityVaultMockStrategy 0xb983C7a6f63623743CeB2F485118a37C9f77d2a0 --verify
```

Verified with:

```sh
ETH_FROM=xxxx ETH_RPC_URL=xxxx ETH_GAS=xxxx dapp verify-contract src/tests/mocks/CharityVaultMockStrategy.sol:CharityVaultMockStrategy 0xfc2004ee942c2483ce5efac20ca8f9ee6c838790 0xb983C7a6f63623743CeB2F485118a37C9f77d2a0
```

Then we trust the strategy from the vault at [0x05F119002D5520B9cE6d62DA89AE5B23020B5d89](https://goerli.etherscan.io/address/0x05F119002D5520B9cE6d62DA89AE5B23020B5d89#writeContract) using the `trustStrategy` method with the previously deployed CharityVaultStrategy address (0xfc2004ee942c2483ce5efac20ca8f9ee6c838790) as the parameter.

#### Execute

```
ETH_FROM=0xf25e32C0f2928F198912A4F21008aF146Af8A05a make deploy-goerli
```

### Custom Network

```
ETH_RPC_URL=<your network> make deploy
```

### Local Testnet

```
# on one terminal
dapp testnet
# get the printed account address from the testnet, and set it as ETH_FROM. Then:
make deploy
```

### Verifying on Etherscan

After deploying your contract you can verify it on Etherscan using:

```
ETHERSCAN_API_KEY=<api-key> contract_address=<address> network_name=<mainnet|rinkeby|...> make verify
```

Check out the [dapp documentation](https://github.com/dapphub/dapptools/tree/master/src/dapp#dapp-verify-contract) to see how
verifying contracts work with DappTools.

## Installing the toolkit

If you do not have DappTools already installed, you'll need to run the below
commands

### Install Nix

```sh
# User must be in sudoers
curl -L https://nixos.org/nix/install | sh

# Run this or login again to use Nix
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

### Install DappTools

```sh
curl https://dapp.tools/install | sh
```

## DappTools Resources

-   [DappTools](https://dapp.tools)
    -   [Hevm Docs](https://github.com/dapphub/dapptools/blob/master/src/hevm/README.md)
    -   [Dapp Docs](https://github.com/dapphub/dapptools/tree/master/src/dapp/README.md)
    -   [Seth Docs](https://github.com/dapphub/dapptools/tree/master/src/seth/README.md)
-   [DappTools Overview](https://www.youtube.com/watch?v=lPinWgaNceM)
-   [Awesome-DappTools](https://github.com/rajivpo/awesome-dapptools)

### FAQS

1. Are users able to permissionlessly create Vaults?

```
A: Yes, users can permissionlessly create Vaults using the [`VaultFactory`](https://github.com/Rari-Capital/vaults/blob/main/src/VaultFactory.sol) `deployVault` function. By extension, the [`CharityVaultsFactory`](https://github.com/Rari-Capital/charity-vaults/blob/main/src/CharityVaultFactory.sol) allows users to deploy [`CharityVaults`](https://github.com/Rari-Capital/charity-vaults/blob/main/src/CharityVault.sol) permissionlessly using it's `deployCharityVault` function.
```

2. How do we envision deposits in a Vault from a ui perspective?
   Say I deposit usdc with one referral link for Charity A with a gift rate of 10% of any interest earned.
   Then I deposit usdc with a different referral link for Charity B with a gift rate of 20% of any interest earned.
   Will the I see a list of the deposits on the UI with each respective interest earned, amount, and gift rate + charity? And I basically have the ability to withdraw x amount from each deposit in one transaction?

```
A:
```

3. Should referrals have the option to choose the underlying asset or does the charity automatically take any donations?

```
A: Yes, Endaoment confirmed they will be able to take any donations.
```

### Erroneous

Transparent fallback functionality was ripped from the CharityVault and CharityVaultFactory to avoid any potential future exploits as well as saving gas on contract deployment.

```
/*///////////////////////////////////////////////////////////////
                    TRANSPARENT FALLBACK FUNCTIONALITY
//////////////////////////////////////////////////////////////*/

/// @notice Erroneous ether sent will be forward to the charity as a donation
receive() external payable {
    (bool sent, ) = CHARITY.call{value: msg.value}("");
    require(sent, "Failed to send to CHARITY");

    // If sent, emit logging event
    emit TransparentTransfer(msg.sender, msg.value);
}
```

### Potential Known Issues

Prettier outputs `[warn] Code style issues found in the above file(s). Forgot to run Prettier?`

-   This is most likely caused by a global installation of prettier without a global installation of the `prettier-solidity-plugin` package. Simply run an `npm install prettier prettier-plugin-solidity -g` to install both packages globally.

Unknown command `jq`

-   Run a `brew install jq`

# License

[GNU Affero GPL v3.0](https://github.com/Anish-Agnihotri/MultiRaffle/blob/master/LICENSE)

# Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. Rari Capital is not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
