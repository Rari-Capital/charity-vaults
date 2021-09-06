pragma solidity ^0.8.6;

import "vaults/VaultFactory.sol";

import {Bytes32AddressLib} from "./libraries/Bytes32AddressLib.sol";

/// @title Fuse Charity Vault Factory
/// @author Transmissions11, JetJadeja, some_random_usc_kids
/// @notice Charity wrapper for vaults/VaultFactory.
contract CharityVaults {
    /// Mirror Transmissions11 + JetJadeja VaultFactory implementation
    using Bytes32AddressLib for *;

    VaultFactory public factory = new VaultFactory();

    /*///////////////////////////////////////////////////////////////
                           STATEFUL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a new Vault contract using the internal VaultFactory.
    /// @dev This will revert if a vault with the token has already been created.
    /// @param underlying Address of the ERC20 token that the Vault will earn yield on.
    /// @return vault The newly deployed Vault contract.
    function deployVault(ERC20 underlying) external returns (Vault vault) {
        // relay call to our internal VaultFactory
        factor.deployVault(underlying);
    }

    /*///////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes a Vault's address from its underlying token.
    /// @dev The Vault returned may not have been deployed yet.
    /// @param underlying The underlying ERC20 token the Vault earns yield on.
    /// @return The Vault that supports this underlying token.
    function getVaultFromUnderlying(ERC20 underlying) external view returns (Vault) {
        // relay call to our internal VaultFactory
        factory.getVaultFromUnderlying(underlying);
    }

    /// @notice Returns if a vault at an address has been deployed yet.
    /// @dev This function is useful to check the return value of
    /// getVaultFromUnderlying, as it may return vaults that have not been deployed yet.
    /// @param vault The address of the vault that may not have been deployed.
    /// @return A bool indicated whether the vault has been deployed already.
    function isVaultDeployed(Vault vault) external view returns (bool) {
        return factory.isVaultDeployed(vault);
    }

    
}
