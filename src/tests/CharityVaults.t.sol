// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import "../CharityVaults.sol";
import {MockERC20} from "solmate/tests/utils/MockERC20.sol";


contract CharityVaultsTest is DSTestPlus {
    CharityVaults charity_vaults;
    MockERC20 underlying;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        charity_vaults = new CharityVaults();
    }


    function test_basic_charity_vault_not_deployed() public {
        assertTrue(
            !charity_vaults.factory().isVaultDeployed(Vault(payable(address(0))))
        );
    }

    function test_charity_vault_deposit_functions_properly(uint256 amount) public {
        // Validate fuzzing value
        if (amount > type(uint256).max / 1e36) return;

        // Mint underlying tokens to deposit into the vault.
        underlying.mint(self, amount);

        // Approve underlying tokens.
        underlying.approve(address(charity_vaults), amount);

        // Deposit
        charity_vaults.deposit(amount, underlying);

        // TODO: Check to make sure CharityVaults has a mapping for user deposit -> CharityDeposit { charity_rate, charity(variable enum?), amount }
    }

    function test_vcharity_ault_withdraw_functions_properly(uint256 amount) public {
        // If the number is too large we can't test with it.
        if (amount > (type(uint256).max / 1e37) || amount == 0) return;

        // Mint, approve, and deposit tokens into the vault.
        test_charity_vault_deposit_functions_properly(amount);

        // Can withdraw full balance from the vault.
        charity_vaults.withdraw(amount, underlying);

        // fvTokens are set to 0.
        assertEq(charity_vaults.getVaultBalance(self, underlying), 0);
        assertEq(underlying.balanceOf(self), amount);

        // TODO: Check to make sure withdraw deleted the CharityVaults mapping for user deposit -> CharityDeposit { charity_rate, charity(variable enum?), amount }
    }
}
