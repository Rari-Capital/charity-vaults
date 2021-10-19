# <h1 align="center"> Charity Vaults </h1>

Share interest from Fuse Vaults with charities, friends, and more.

![Github Actions](https://github.com/Rari-Capital/charity-vaults/workflows/Tests/badge.svg)

### Getting Started

```sh
git clone https://github.com/Rari-Capital/charity-vaults.git
cd charity-vaults
make
make test
```


### Credits

- [t11s](https://twitter.com/transmissions11), [Jet Jadeja](https://twitter.com/JetJadeja), and [David Lucid](https://twitter.com/davidlucid) for the exceptional guidance.
- [Georgios Konstantopoulos](https://github.com/gakonst) for the amazing [dapptools-template](https://github.com/gakonst/dapptools-template) resource.


### Generate Pretty Visuals

We use [surya](https://github.com/ConsenSys/surya) to create contract diagrams.

Run `npm run visualize` to generate an amalgamated contract visualization in the `./assets/` directory. Or use the below commands for each respective contract.

##### CharityVault.sol

Run `surya graph -s src/CharityVault.sol | dot -Tpng > assets/CharityVault.png`

#### CharityVaultFactory.sol

Run `surya graph -s src/CharityVaultFactory.sol | dot -Tpng > assets/CharityVaultFactory.png`


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

### Testnet Deployement


⚠️ ⚠️ ⚠️ Requirements ⚠️ ⚠️ ⚠️
```md
Using the `--verify` flag requires an
`ETHERSCAN_API_KEY` environment variable
which can be set in a `.env` file with:
`ETHERSCAN_API_KEY=<API_KEY>`.
```

To deploy to a testnet, we need to first deploy the [vaults](https://github.com/Rari-Capital/vaults) contracts.

- First, the VaultFactory contract: `dapp create lib/vaults/src/VaultFactory --verify`
- Next, the Vault contract: `dapp create lib/vaults/src/Vault --verify`

Now, we can move on to deploying our CharityVaults.

- Deploy the CharityVaultFactory contract: `dapp create CharityVaultFactory --verify`
- Deploy the CharityVault contract: `dapp create CharityVault --verify`


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

* [DappTools](https://dapp.tools)
    * [Hevm Docs](https://github.com/dapphub/dapptools/blob/master/src/hevm/README.md)
    * [Dapp Docs](https://github.com/dapphub/dapptools/tree/master/src/dapp/README.md)
    * [Seth Docs](https://github.com/dapphub/dapptools/tree/master/src/seth/README.md)
* [DappTools Overview](https://www.youtube.com/watch?v=lPinWgaNceM)
* [Awesome-DappTools](https://github.com/rajivpo/awesome-dapptools)



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

*The below questions refer to how the ui links the charities*
*Like we were thinking, the charities/referrals would be a json list with referral/charity_id to gift_address that can be pr'd into the repo like tokenlists*
*Then all deposits on the ui will pass in the gift address*

*If we want, we can have charities be tracked onchain*

4. Is anybody able to be a charity - like is adding a charity permissionless?
(from the project description it sounds like it can be anyone)
```
A:
```

5. Should referrals have the gift rate optionally set by the charity or it should always be up to the user depositing?
(We _could_ always just not have the ui for the charity to set the rate for a given referral and always allow the user to pass in a gift rate and we verify that the charity didn't already set the rate manually and in that case revert the deposit tx)
```
A:
```

6. *If* the charity is able to set the gift rate, are they able to change the rate for a given referral?
```
A:
```

7. *If* the charity is able to set the gift rate, is anybody able to create a referral link for that charity with a given rate? On the other hand if the charity isn't able to set the gift rate, is a referral link automatically generated for a given charity when a charity is added to the CharityVaults contract?
(from the project description it sounds like it can be anyone)
```
A:
```

8. On withdrawal, it doesn't look like we are able to control where the vault.withdraw function sends the funds?
```
A:


9. Is there a benefit to storing the Charity data (name, "verified" status) on-chain?

A:


10. Should we aim to make the charity vault ownership transferable? Or is maintaining ownership per-address acceptable?

A:
```