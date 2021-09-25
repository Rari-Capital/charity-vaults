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
      assertTrue(factory.isVaultDeployed(cvault));
      assertERC20Eq(cvault.underlying(), underlying);
    }

    // function test_charity_vault_deposit_functions_properly(uint256 amount) public {
    //     // Validate fuzzing value
    //     if (amount > type(uint256).max / 1e36) return;

    //     // Mint underlying tokens to deposit into the vault.
    //     underlying.mint(self, amount);

    //     // Approve underlying tokens.
    //     underlying.approve(address(factory), amount);

    //     // Deposit
    //     factory.deposit(amount, underlying);

    //     // TODO: Check to make sure CharityVaults has a mapping for user deposit -> CharityDeposit { charity_rate, charity(variable enum?), amount }
    // }

    // function test_vcharity_ault_withdraw_functions_properly(uint256 amount) public {
    //     // If the number is too large we can't test with it.
    //     if (amount > (type(uint256).max / 1e37) || amount == 0) return;

    //     // Mint, approve, and deposit tokens into the vault.
    //     test_charity_vault_deposit_functions_properly(amount);

    //     // Can withdraw full balance from the vault.
    //     charity_vaults.withdraw(amount, underlying);

    //     // fvTokens are set to 0.
    //     assertEq(charity_vaults.getVaultBalance(self, underlying), 0);
    //     assertEq(underlying.balanceOf(self), amount);

    //     // TODO: Check to make sure withdraw deleted the CharityVaults mapping for user deposit -> CharityDeposit { charity_rate, charity(variable enum?), amount }
    // }
}
