// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

import "vaults/VaultFactory.sol";

// import {Bytes32AddressLib} from "./libraries/Bytes32AddressLib.sol";

/// @title Fuse Charity Vault Factory
/// @author Transmissions11, JetJadeja, some_random_usc_kids
/// @notice Charity wrapper for vaults/VaultFactory.
contract CharityVaults {
    /// @dev This factory is already deployed
    VaultFactory public factory;

    /// @notice Creates a CharityVault
    constructor(address _deployed_vault_factory) {
        charities = new Charity[]();
        factory = new VaultFactory(_deployed_vault_factory);
    }

    /// @notice Deposit
    struct Deposit {
        uint256 deposit_id;
        address payable gift_address;
        // TODO: make deposits transferrable through an NFT
        /// TODO: add assets in the Charity Vault - then we swap through uniswap v3
    }

    /// @notice mapping from deposit_id to Deposit
    mapping(uint256 => Deposit) deposits;

    /// @notice mapping from user to their deposits
    mapping(address => uint256[]) users_deposits;

    /// @notice track latest deposit_id
    uint256 max_deposit_id;

    /// @notice Deposit the vault's underlying token to mint fvTokens.
    /// @param underlyingAmount The amount of the underlying token to deposit.
    /// @param underlying The underlying ERC20 token the Vault earns yield on.
    /// @param giftAddress The payable address for the gift interest to be sent to.
    /// @param giftRate The percent rate for the gift interest.
    function deposit(
        uint256 underlyingAmount,
        ERC20 underlying,
        address payable giftAddress,
        uint256 giftRate
    ) external {
        // Get the respective Vault
        Vault vault = factory.getVaultFromUnderlying(underlying);

        // TODO: can this function should take a list of deposits for various vaults/underlying assets,

        max_deposit_id += 1;
        uint256 deposit_id = max_deposit_id;
        deposits[deposit_id] = new Deposit(
            deposit_id,
            vault,
            underlyingAmount,
            giftAddress,
            giftRate
        );
        user_deposits[msg.sender].push(deposit_id);

        // Relay deposit to the respective vault
        vault.deposit(underlyingAmount);
    }

    /// @notice Burns fvTokens and sends underlying tokens to the caller.
    /// @param amount The amount of fvTokens to redeem for underlying tokens.
    function withdraw(
        uint256 amount,
        ERC20 underlying,
        uint256 deposit_id
    ) external {
        // Get the respective Vault
        Vault vault = factory.getVaultFromUnderlying(underlying);

        // TODO: this function should take a list of withdraws for various vaults/underlying assets,

        // Fetch the Deposit Object from the provided deposit_id
        Deposit deposit = deposits[deposit_id];

        // TODO: determine charity rate withdraw mechanics

        // Send the gift amount to the charity
        // TODO: how to send from the vault to the deposit.gift_address

        // Withdraw the rest to the user
        // vault.withdraw();
    }

    /// @notice Fetches the user's balance for the Vault with the provided underlying asset
    /// @param user A given EOA.
    /// @param underlying The underlying ERC20 token the Vault earns yield on.
    /// @return uint256 The balance of the user for the specified vault
    function getVaultBalance(address user, ERC20 underlying)
        external
        view
        returns (uint256)
    {
        // Get the respective Vault
        Vault vault = factory.getVaultFromUnderlying(underlying);

        // Return the balanceOf user
        return vault.balanceOf(user);
    }
}
