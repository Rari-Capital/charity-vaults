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
        // Compute a CharityVault Salt
        bytes32 cvaultSalt = keccak256(
            abi.encodePacked(
                address(underlying),
                charity,
                feePercent
            )
        );
        
        // Use the create2 opcode to deploy a CharityVault contract.
        // This will revert if a vault with this underlying has already been 
        // deployed, as the salt would be the same and we can't deploy with it twice.
        cvault = new CharityVault{salt: cvaultSalt}(underlying, charity, feePercent);

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
    function getCharityVaultFromUnderlying(ERC20 underlying, address payable charity, uint256 feePercent) external view returns (CharityVault) {
        // Compute a CharityVault's Salt
        bytes32 cvaultSalt = keccak256(
            abi.encodePacked(
                address(underlying),
                charity,
                feePercent
            )
        );

        // Compute the create2 hash.
        bytes32 create2Hash = keccak256(
            abi.encodePacked(
                // Prefix:
                bytes1(0xFF),
                // Creator:
                address(this),
                // Salt:
                cvaultSalt,
                // Bytecode hash:
                keccak256(
                    abi.encodePacked(
                        // Deployment bytecode:
                        type(CharityVault).creationCode,
                        // Constructor arguments:
                        abi.encodePacked(
                            address(underlying),
                            charity,
                            feePercent
                        )
                    )
                )
            )
        );

        // Convert the create2 hash into a CharityVault.
        return CharityVault(payable(create2Hash.toAddress()));
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
