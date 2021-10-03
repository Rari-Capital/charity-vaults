// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

import {MockERC20} from "solmate/tests/utils/MockERC20.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {CharityVault} from "../CharityVault.sol";
import {Vault} from 'vaults/Vault.sol';

contract CharityVaultTest is DSTestPlus {
    Vault vault;
    CharityVault cvault;
    MockERC20 underlying;
    address payable immutable caddress = payable(address(0));
    uint256 immutable cfeePercent = 10;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vault = new Vault(underlying);
        vault.setFeeClaimer(address(1));
        cvault = new CharityVault(underlying, caddress, cfeePercent, vault);
    }

    /// @notice Tests if we can deploy a charity vault with valid fuzzed parameters
    function test_deploy_charity_vault(address payable _address, uint256 _feePercent) public {
        // ** We can ignore out of range fee percents
        if(_feePercent > 100 || _feePercent < 0) return;

        CharityVault newVault = new CharityVault(underlying, _address, _feePercent, vault);
        
        // Assert our CharityVault parameters are equal
        assertTrue(address(newVault).code.length > 0);
        // assertEq(caddress, newVault.charity());
        // assertEq(cfeePercent, newVault.feePercent());
        // assertERC20Eq(newVault.underlying(), underlying);
    }

    /// @notice Tests if deployment fails for invalid parameters
    function testFail_deploy_charity_vault(address payable _address, uint256 _feePercent) public {
        // ** We should fail for valid feePercents - only testing invalid params
        assertFalse(_feePercent <= 100 || _feePercent >= 0);

        CharityVault _newVault = new CharityVault(underlying, _address, _feePercent, vault);
    }

    /// @notice we shouldn't be able to deploy multiple charity vaults with the same configuration
    // function testFail_deploy_equal_config_cvaults() public {
    //     test_deploy_charity_vault(caddress, cfeePercent);
    //     test_deploy_charity_vault(caddress, cfeePercent);
    // }

    // /// @notice we should, however, be able to deploy charity vaults with slightly varying parameters
    // function test_deploys_vaults_varying_params() public {
    //     test_deploy_charity_vault(payable(address(0)), 5);
    //     test_deploy_charity_vault(payable(address(1)), 5);
    //     test_deploy_charity_vault(payable(address(0)), cfeePercent);
    //     test_deploy_charity_vault(payable(address(1)), cfeePercent);
    // }

    // function test_basic_charity_vault_not_deployed() public {
    //     assertTrue(
    //         !cvault.factory().isVaultDeployed(Vault(payable(address(0))))
    //     );
    // }

    // function test_charity_vault_deposit_functions_properly(uint256 amount) public {
    //     // Validate fuzzing value
    //     if (amount > type(uint256).max / 1e36) return;

    //     // Mint underlying tokens to deposit into the vault.
    //     underlying.mint(self, amount);

    //     // Approve underlying tokens.
    //     underlying.approve(address(cvault), amount);

    //     // Deposit
    //     cvault.deposit(amount, underlying);

    //     // TODO: Check to make sure CharityVaults has a mapping for user deposit -> CharityDeposit { charity_rate, charity(variable enum?), amount }
    // }

    // function test_vcharity_ault_withdraw_functions_properly(uint256 amount) public {
    //     // If the number is too large we can't test with it.
    //     if (amount > (type(uint256).max / 1e37) || amount == 0) return;

    //     // Mint, approve, and deposit tokens into the vault.
    //     test_charity_vault_deposit_functions_properly(amount);

    //     // Can withdraw full balance from the vault.
    //     cvault.withdraw(amount, underlying);

    //     // fvTokens are set to 0.
    //     assertEq(cvault.getVaultBalance(self, underlying), 0);
    //     assertEq(underlying.balanceOf(self), amount);

    //     // TODO: Check to make sure withdraw deleted the CharityVaults mapping for user deposit -> CharityDeposit { charity_rate, charity(variable enum?), amount }
    // }
}
