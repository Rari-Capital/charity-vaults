// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

import {MockERC20} from "solmate/tests/utils/MockERC20.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import "../CharityVaultFactory.sol";
import "../CharityVault.sol";

contract CharityVaultFactoryTest is DSTestPlus {
    CharityVaultFactory factory;
    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        factory = new CharityVaultFactory();
    }


    // The CharityVaultFactory should not be able to find a deployed vault for anything initially
    function test_basic_charity_vault_not_deployed(address fuzzed_addr) public {
        assertTrue(
            !factory.isVaultDeployed(CharityVault(payable(fuzzed_addr)))
        );
    }

    /// @notice we can deploy a CharityVault
    /// @dev uses the same testing pattern as VaultFactory for consistency
    function test_able_to_deploy_charity_vault_from_factory(address fuzzed_addr, uint256 feePercent) public {
      // Validate fuzzed fee percent
      if (feePercent > type(uint256).max / 1e36) return;

      // Deploy the CharityVault
      CharityVault cvault = factory.deployCharityVault(underlying, payable(fuzzed_addr), feePercent);

      // Ensure the CharityVault is actually deployed
      assertVaultEq(factory.getCharityVaultFromUnderlying(underlying, payable(fuzzed_addr), feePercent), cvault);
      assertTrue(factory.isCharityVaultDeployed(cvault));
      assertERC20Eq(cvault.underlying(), underlying);
    }

    function testFail_does_not_allow_duplicate_vaults() public {
        test_able_to_deploy_charity_vault_from_factory();
        test_able_to_deploy_charity_vault_from_factory();
    }
}
