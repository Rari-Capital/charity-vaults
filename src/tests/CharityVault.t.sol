// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

/* solhint-disable func-name-mixedcase */

import {MockERC20} from "solmate/test/utils/MockERC20.sol";

import {Vault} from "vaults/Vault.sol";
import {VaultFactory} from "vaults/VaultFactory.sol";
import {MockStrategy} from "vaults/test/mocks/MockStrategy.sol";
import {DSTestPlus} from "vaults/test/utils/DSTestPlus.sol";

import {CharityVault} from "../CharityVault.sol";
import {CharityVaultFactory} from "../CharityVaultFactory.sol";

contract CharityVaultTest is DSTestPlus {
    MockERC20 public underlying;

    /// @dev Vault Logic
    Vault public vault;
    VaultFactory public vaultFactory;
    MockStrategy public strategy1;
    MockStrategy public strategy2;

    /// @dev CharityVault Logic
    CharityVault public cvault;
    CharityVaultFactory public cvaultFactory;
    address payable public immutable caddress = payable(address(0));
    uint256 public immutable cfeePercent = 10;
    uint256 public nonce = 1;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vaultFactory = new VaultFactory();
        vault = vaultFactory.deployVault(underlying);

        strategy1 = new MockStrategy(underlying);
        strategy2 = new MockStrategy(underlying);

        cvaultFactory = new CharityVaultFactory(address(vaultFactory));
        cvault = cvaultFactory.deployCharityVault(
            underlying,
            caddress,
            cfeePercent
        );
    }

    /// @dev Constructing a lone CharityVault should fail from the Auth modifier in the CharityVault Constructor
    function testFail_construct_lone_cv() public {
        MockERC20 _underlying = new MockERC20("Fail Mock Token", "FAIL", 18);
        Vault _vault = new VaultFactory().deployVault(_underlying);

        // this should fail
        new CharityVault(_underlying, caddress, cfeePercent, _vault);
    }

    /// @notice Tests to make sure the deployed ERC20 metadata is correct
    function test_properly_init_erc20() public {
        assertERC20Eq(cvault.UNDERLYING(), underlying);
        assertEq(
            cvault.name(),
            string(
                abi.encodePacked("Rari ", underlying.name(), " Charity Vault")
            )
        );
        assertEq(
            cvault.symbol(),
            string(abi.encodePacked("rcv", underlying.symbol()))
        );
    }

    /// @notice Tests if we can deploy a charity vault with valid fuzzed parameters
    function test_deploy_charity_vault(
        address payable _address,
        uint256 _feePercent
    ) public {
        uint256 validatedFeePercent = _feePercent;
        if (_feePercent > 100 || _feePercent < 0) {
            validatedFeePercent =
                uint256(
                    keccak256(
                        abi.encodePacked(block.timestamp, msg.sender, nonce)
                    )
                ) %
                100;
            nonce++;
        }

        CharityVault newVault = cvaultFactory.deployCharityVault(
            underlying,
            _address,
            validatedFeePercent
        );

        // Assert our CharityVault parameters are equal
        assertTrue(address(newVault).code.length > 0);
        assertEq(_address, newVault.CHARITY());
        assertEq(validatedFeePercent, newVault.BASE_FEE());
        assertERC20Eq(newVault.UNDERLYING(), underlying);
    }

    /// @notice Tests if deployment fails for invalid parameters
    function testFail_deploy_charity_vault(
        address payable _address,
        uint256 _feePercent
    ) public {
        uint256 validatedFeePercent = _feePercent;
        if (_feePercent <= 100 || _feePercent >= 0) {
            validatedFeePercent =
                uint256(
                    keccak256(
                        abi.encodePacked(block.timestamp, msg.sender, nonce)
                    )
                ) +
                101;
            nonce++;
        }

        // this should fail
        cvaultFactory.deployCharityVault(
            underlying,
            _address,
            validatedFeePercent
        );
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

    //     // TODO: Check to make sure CharityVaults
    //     // has a mapping for user deposit -> CharityDeposit { charity_rate, charity(variable enum?), amount }
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

    //     // TODO: Check to make sure withdraw deleted the CharityVaults
    //     // mapping for user deposit -> CharityDeposit { charity_rate, charity(variable enum?), amount }
    // }
}

/* solhint-enable func-name-mixedcase */
