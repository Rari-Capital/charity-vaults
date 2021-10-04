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
    uint256 nonce = 1;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vault = new Vault(underlying);
        vault.setFeeClaimer(address(1));
        cvault = new CharityVault(underlying, caddress, cfeePercent, vault);
    }

    /// @notice Tests to make sure the deployed ERC20 metadata is correct
    function test_properly_init_erc20() public {
        assertERC20Eq(cvault.underlying(), underlying);
        assertEq(cvault.name(), string(abi.encodePacked("Fuse ", underlying.name(), " Charity Vault")));
        assertEq(cvault.symbol(), string(abi.encodePacked("fcv", underlying.symbol())));
    }

    /// @notice Tests if we can deploy a charity vault with valid fuzzed parameters
    function test_deploy_charity_vault(address payable _address, uint256 _feePercent) public {
        uint256 validatedFeePercent = _feePercent;
        if(_feePercent > 100 || _feePercent < 0) {
            validatedFeePercent = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 100;
            nonce++;
        }

        CharityVault newVault = new CharityVault(underlying, _address, validatedFeePercent, vault);
        
        // Assert our CharityVault parameters are equal
        assertTrue(address(newVault).code.length > 0);
        assertEq(_address, newVault.charity());
        assertEq(validatedFeePercent, newVault.feePercent());
        assertERC20Eq(newVault.underlying(), underlying);
    }

    /// @notice Tests if deployment fails for invalid parameters
    function testFail_deploy_charity_vault(address payable _address, uint256 _feePercent) public {
        uint256 validatedFeePercent = _feePercent;
        if(_feePercent <= 100 || _feePercent >= 0) {
            validatedFeePercent = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) + 101;
            nonce++;
        }

        CharityVault _newVault = new CharityVault(underlying, _address, validatedFeePercent, vault);
    }

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
