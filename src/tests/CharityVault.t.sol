// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

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
    function testFailConstructCharityVault() public {
        MockERC20 _underlying = new MockERC20("Fail Mock Token", "FAIL", 18);
        Vault _vault = new VaultFactory().deployVault(_underlying);

        // this should fail
        new CharityVault(_underlying, caddress, cfeePercent, _vault);
    }

    /// @notice Tests to make sure the deployed ERC20 metadata is correct
    function testProperlyInitErc20() public {
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
    function testDeployCharityVault(
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
    function testFailDeployCharityVault(
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

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Test depositing into CharityVault
    function testDepositIntoCharityVault(
        uint256 depositAmount
    ) public {
        // First burn any underlying tokens
        // TODO: send to papa Vitalik's addy
        underlying.transfer(address(0x0), underlying.balanceOf(address(this)));

        // Mint underlying tokens to deposit into the vault.
        underlying.mint(address(this), depositAmount);

        // ?? Approve underlying tokens. ??
        // underlying.approve(address(cvault), amount);

        // Deposit Tokens into the CharityVault
        cvault.deposit(depositAmount);

        // Assert that we now have `depositAmount` rcvTokens
        assertEq(cvault.balanceOf(address(this)), depositAmount);
    }

    /// @notice Test Charity Withdrawal from CharityVault
    function testCharityVaultWithdrawal() public {
        cvault.withdrawInterestToCharity();
    }

    /// @notice Test that we cannot deposit more than the approved amount of underlying
    function testFailDepositWithNotEnoughApproval() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(cvault), 0.5e18);

        cvault.deposit(1e18);
    }

    function testFailWithdrawWithNotEnoughBalance() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(cvault), 0.5e18);

        cvault.deposit(0.5e18);

        cvault.withdraw(1e18);
    }

    function testFailRedeemWithNotEnoughBalance() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(cvault), 0.5e18);

        cvault.deposit(0.5e18);

        // cvault.redeem(1e18);
    }

    // function testFailRedeemWithNoBalance() public {
    //     vault.redeem(1e18);
    // }

    function testFailWithdrawWithNoBalance() public {
        cvault.withdraw(1e18);
    }

    function testFailDepositWithNoApproval() public {
        cvault.deposit(1e18);
    }

    // function testFailRedeemZero() public {
    //     cvault.redeem(0);
    // }

    function testFailWithdrawZero() public {
        cvault.withdraw(0);
    }

    function testFailDepositZero() public {
        cvault.deposit(0);
    }
}
