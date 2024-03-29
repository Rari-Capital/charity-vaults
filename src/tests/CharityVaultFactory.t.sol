// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

/* solhint-disable func-name-mixedcase */

import {Authority} from "solmate/auth/Auth.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {VaultFactory} from "vaults/VaultFactory.sol";
import {Vault} from "vaults/Vault.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {CharityVaultFactory} from "../CharityVaultFactory.sol";
import {CharityVault} from "../CharityVault.sol";

contract CharityVaultFactoryTest is DSTestPlus {
    CharityVaultFactory public factory;
    VaultFactory public vaultFactory;
    MockERC20 public underlying;

    /// @dev For _random_ feePercent generation
    uint256 public nonce = 1;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vaultFactory = new VaultFactory(address(this), Authority(address(0)));
        factory = new CharityVaultFactory(address(vaultFactory));
    }

    /// @dev Helper function refactoring logic to deploy a single Vault
    function deploy_vault(MockERC20 _underlying) public {
        // First deploy the Vault and ensure
        Vault vault = vaultFactory.deployVault(_underlying);
        assertVaultEq(vaultFactory.getVaultFromUnderlying(_underlying), vault);
        assertTrue(vaultFactory.isVaultDeployed(vault));
        assertERC20Eq(vault.UNDERLYING(), _underlying);
    }

    /// @dev Helper function to refactor deploying a cvault from the cvault factory
    function deploy_cvault(
        MockERC20 _underlying,
        address payable _address,
        uint256 _feePercent
    ) public {
        // Validate fuzzed fee percent
        if (_feePercent > type(uint256).max / 1e36) return;

        // Deploy the CharityVault
        CharityVault cvault = factory.deployCharityVault(
            _underlying,
            payable(_address),
            _feePercent
        );

        // Ensure the CharityVault is actually deployed
        assertTrue(factory.isCharityVaultDeployed(cvault));
        assertERC20Eq(cvault.UNDERLYING(), _underlying);
        //   assertCharityVaultEq(factory.getCharityVaultFromUnderlying(
        //   _underlying, payable(_address), _feePercent), cvault);
    }

    /// @dev The CharityVaultFactory should not be able to find
    /// @dev a deployed vault for nonexistant Vaults
    function test_basic_charity_vault_not_deployed(
        address payable fuzzedAddress
    ) public {
        assertFalse(
            factory.isCharityVaultDeployed(CharityVault(payable(fuzzedAddress)))
        );
    }

    /// @notice we can deploy a CharityVault
    /// @dev Checks for previously deployed vaults
    /// @dev Validates fee percent params, and coalesces using semi-random hashes
    function test_able_to_deploy_cvault_from_factory(
        address payable fuzzedAddress,
        uint256 feePercent
    ) public {
        if (
            !vaultFactory.isVaultDeployed(
                vaultFactory.getVaultFromUnderlying(underlying)
            )
        ) {
            deploy_vault(underlying);
        }

        uint256 validatedFeePercent = feePercent;
        if (feePercent > 100 || feePercent < 0) {
            validatedFeePercent =
                uint256(
                    keccak256(
                        abi.encodePacked(block.timestamp, msg.sender, nonce)
                    )
                ) %
                100;
            nonce++;
        }
        deploy_cvault(underlying, fuzzedAddress, validatedFeePercent);
    }

    /// @notice we need to make sure we can't deploy charity vaults with fee percents outside our constraints
    function testFail_deploy_cvault_with_high_fee_percent(
        address payable fuzzedAddress,
        uint256 feePercent
    ) public {
        // Filter out valid fuzzed feePercents
        uint256 validatedFeePercent = feePercent;
        if (feePercent <= 100 || feePercent >= 0) {
            validatedFeePercent =
                uint256(
                    keccak256(
                        abi.encodePacked(block.timestamp, msg.sender, nonce)
                    )
                ) +
                101;
            nonce++;
        }
        assertFalse(validatedFeePercent > type(uint256).max / 1e36);

        if (
            !vaultFactory.isVaultDeployed(
                vaultFactory.getVaultFromUnderlying(underlying)
            )
        ) {
            deploy_vault(underlying);
        }
        // This deploy should fail since the fee percent is out of bounds
        deploy_cvault(underlying, fuzzedAddress, validatedFeePercent);
    }

    /// @notice deploying similar CharityVaults should only fail when
    /// @notice underlying, fuzzedAddress, and feePercent are the same
    function testFail_does_not_allow_duplicate_cvaults(
        address payable fuzzedAddress,
        uint256 feePercent
    ) public {
        deploy_vault(underlying);
        // ** We need to assertFalse for high fee percent so test doesn't pass (return) in the deploy_cvault function
        assertFalse(feePercent > type(uint256).max / 1e36);
        deploy_cvault(underlying, fuzzedAddress, feePercent);
        deploy_cvault(underlying, fuzzedAddress, feePercent);
    }

    /// @notice Makes sure we can deploy same charity address and feePercents for different underlying tokens
    function test_can_deploy_different_underlying_cvaults(
        address payable fuzzedAddress,
        uint256 feePercent
    ) public {
        if (
            !vaultFactory.isVaultDeployed(
                vaultFactory.getVaultFromUnderlying(underlying)
            )
        ) {
            deploy_vault(underlying);
        }

        uint256 validatedFeePercent = feePercent;
        if (feePercent > 100 || feePercent < 0) {
            validatedFeePercent =
                uint256(
                    keccak256(
                        abi.encodePacked(block.timestamp, msg.sender, nonce)
                    )
                ) %
                100;
            nonce++;
        }
        deploy_cvault(underlying, fuzzedAddress, validatedFeePercent);

        // Try to deploy the same charity address and feePercent for different underlyings
        MockERC20 underlying2 = new MockERC20("Mock Token 2", "TKN2", 18);
        deploy_cvault(underlying2, fuzzedAddress, validatedFeePercent);
    }
}

/* solhint-enable func-name-mixedcase */
