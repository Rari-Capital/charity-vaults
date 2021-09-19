// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {Bytes32AddressLib} from "./libraries/Bytes32AddressLib.sol";
import "./CharityVault.sol";

/// @title Fuse Charity Vault Factory
/// @author Transmissions11, JetJadeja, Andreas Bigger
/// @notice Charity wrapper for vaults/VaultFactory.
contract CharityVaultFactory {
    using Bytes32AddressLib for *;

    /// @dev Maps bytes32 hash of underlying erc20 token + charity donation address + fee percent to a CharityVault
    mapping(bytes32 => address) public cvaults;
    mapping(bytes32 => bool) public cvaultExists;



    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when `deployCharityVault` is called.
    /// @param underlying The underlying token used in the vault.
    /// @param vault The new charity vault deployed that accepts the underlying token.
    event CharityVaultDeployed(ERC20 underlying, CharityVault vault);

    /*///////////////////////////////////////////////////////////////
                           STATEFUL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy a new CharityVault contract that supports a specific underlying asset.
    /// @dev This will revert if a vault with the token has already been created.
    /// @param underlying Address of the ERC20 token that the Vault will earn yield on.
    /// @param charity donation address
    /// @param feePercent percent of earned interest sent to the charity as a donation
    /// @return cvault The newly deployed CharityVault contract.
    function deployCharityVault(ERC20 underlying, address payable charity, uint256 feePercent) external returns (CharityVault cvault) {
        // Compute a CharityVault Hash
        // TODO: how to compute the hash of the parameters
        bytes32 cvaultHash = keccak256(
            abi.encodePacked(
                address(underlying),
                charity,
                feePercent
            )
        );

        require(cvaultExists[cvaultHash], "Charity Vault already exists!");
        
        // Use the create2 opcode to deploy a CharityVault contract.
        // This will revert if a vault with this underlying has already been 
        // deployed, as the salt would be the same and we can't deploy with it twice.
        cvault = new CharityVault{salt: cvaultHash}(underlying, charity, feePercent);

        // Map the parameters to our new CharityVault
        cvaults[cvaultHash] = address(cvault);
        cvaultExists[cvaultHash] = true;
        emit CharityVaultDeployed(underlying, cvault);
    }

    /*///////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes a CharityVault's address from its underlying token, donation address, and fee percent.
    /// @dev The CharityVault returned may not have been deployed yet.
    /// @param underlying The underlying ERC20 token the CharityVault earns yield on.
    /// @param charity donation address
    /// @param feePercent percent of earned interest sent to the charity as a donation
    /// @return The CharityVault that supports this underlying token.
    function getCharityVaultFromUnderlying(ERC20 underlying, address payable charity, uint256 feePercent) external view returns (Vault) {
        // Compute a CharityVault Hash
        // TODO: how to compute the hash of the parameters
        bytes32 cvaultHash = keccak256(
            abi.encodePacked(
                address(underlying),
                charity,
                feePercent
            )
        );

        // Fetch the given CharityVault from the hash of it's parameters
        return CharityVault(payable(cvaults[cvaultHash]));
    }

    /// @notice Returns if a charity vault at an address has been deployed yet.
    /// @dev This function is useful to check the return value of
    /// getCharityVaultFromUnderlying, as it may return vaults that have not been deployed yet.
    /// @param cvault The address of the charity vault that may not have been deployed.
    /// @return A bool indicated whether the charity vault has been deployed already.
    function isCharityVaultDeployed(CharityVault cvault) external view returns (bool) {
        return address(cvault).code.length > 0;
    }

}
