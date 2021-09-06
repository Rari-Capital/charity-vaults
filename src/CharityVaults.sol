// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

import "vaults/VaultFactory.sol";

// import {Bytes32AddressLib} from "./libraries/Bytes32AddressLib.sol";

/// @title Fuse Charity Vault Factory
/// @author Transmissions11, JetJadeja, some_random_usc_kids
/// @notice Charity wrapper for vaults/VaultFactory.
contract CharityVaults {

    VaultFactory public factory = new VaultFactory();

    /// @notice Deposit the vault's underlying token to mint fvTokens.
    /// @param underlyingAmount The amount of the underlying token to deposit.
    /// @param underlying The underlying ERC20 token the Vault earns yield on.
    function deposit(uint256 underlyingAmount, ERC20 underlying) external {
        // Get the respective Vault
        Vault vault = factory.getVaultFromUnderlying(underlying);
        
        // TODO: determine charity rate mechanics 

        // Relay deposit to the respective vault
        vault.deposit(underlyingAmount);
    }

    /// @notice Burns fvTokens and sends underlying tokens to the caller.
    /// @param amount The amount of fvTokens to redeem for underlying tokens.
    function withdraw(uint256 amount, ERC20 underlying) external {
        // Get the respective Vault
        Vault vault = factory.getVaultFromUnderlying(underlying);

        // TODO: determine charity rate withdraw mechanics 

        // Relay withdraw to the respective vault
        vault.withdraw(amount);
    }

    /// @notice Fetches the user's balance for the Vault with the provided underlying asset
    /// @param user A given EOA.
    /// @param underlying The underlying ERC20 token the Vault earns yield on.
    /// @return uint256 The balance of the user for the specified vault
    function getVaultBalance(address user, ERC20 underlying) external view returns (uint256) {
        // Get the respective Vault
        Vault vault = factory.getVaultFromUnderlying(underlying);

        // Return the balanceOf user
        return vault.balanceOf(user);
    }
}
