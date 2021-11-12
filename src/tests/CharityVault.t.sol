// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.9;

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Vault} from "vaults/Vault.sol";
import {VaultFactory} from "vaults/VaultFactory.sol";
import {MockStrategy} from "vaults/test/mocks/MockStrategy.sol";
import {DSTestPlus} from "vaults/test/utils/DSTestPlus.sol";

import {CharityVaultMockStrategy} from "./mocks/CharityVaultMockStrategy.sol";
import {CharityVault} from "../CharityVault.sol";
import {CharityVaultFactory} from "../CharityVaultFactory.sol";

contract CharityVaultTest is DSTestPlus {
    using FixedPointMathLib for uint256;

    MockERC20 public underlying;

    /// @dev Vault Logic
    Vault public vault;
    VaultFactory public vaultFactory;
    MockStrategy public strategy1;
    MockStrategy public strategy2;
    CharityVaultMockStrategy public cvStrategy;

    /// @dev CharityVault Logic
    CharityVault public cvault;
    CharityVaultFactory public cvaultFactory;
    // address payable public immutable caddress = payable(address(0));
    address payable public caddress;
    uint256 public immutable cfeePercent = 10;
    uint256 public nonce = 1;

    /// @dev BASE_UNIT variable used in the contract
    uint256 public immutable BASE_UNIT = 10**18;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vaultFactory = new VaultFactory();
        vault = vaultFactory.deployVault(underlying);

        vault.setFeePercent(0.1e18);
        vault.setHarvestDelay(6 hours);
        vault.setHarvestWindow(5 minutes);
        vault.setTargetFloatPercent(0.01e18);

        vault.initialize();

        strategy1 = new MockStrategy(underlying);
        strategy2 = new MockStrategy(underlying);
        cvStrategy = new CharityVaultMockStrategy(underlying);

        // Create a mock strategy to act as the charity //
        MockStrategy mockCharity = new MockStrategy(new MockERC20("Random Token", "RNDM", 18));
        caddress = payable(address(mockCharity));

        cvaultFactory = new CharityVaultFactory(address(vaultFactory));
        cvault = cvaultFactory.deployCharityVault(
            underlying,
            caddress,
            cfeePercent
        );

        // ** Set cvault as authorizaed
        vault.setAuthority(cvault.authority());
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
                    BASIC DEPOSIT/WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Tests depositing and withdrawing into the Charity Vault
    function testAtomicDepositWithdraw() public {
        underlying.mint(address(this), 1e18);
        underlying.approve(address(cvault), 1e18);

        // Track balance prior to deposit
        uint256 preDepositBal = underlying.balanceOf(address(this));
        cvault.deposit(1e18);

        // After a successfull Charity Vault Deposit,
        // the vault should contain the amount underlying token
        assertEq(vault.exchangeRate(), 10**vault.decimals());
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - 1e18);

        // The vault should have no balance for this depositor
        assertEq(vault.balanceOf(address(this)), 0);

        // The vault should have mapped the underlying token to the cvault
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);

        // The user should be minted rcvTokens 1:1 to the underlying token
        assertEq(cvault.balanceOf(address(this)), 1e18);

        cvault.withdraw(1e18);

        // Vault Balances
        assertEq(vault.exchangeRate(), 10**vault.decimals());
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalHoldings(), 0);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(this)), 0);

        // The vault should have no underlying balance for the Charity Vault
        assertEq(vault.balanceOfUnderlying(address(cvault)), 0);
        assertEq(vault.balanceOf(address(cvault)), 0);

        // The Charity Vault should now have no rcvTokens for the Depositor
        assertEq(cvault.balanceOf(address(this)), 0);

        // Depositor Balances
        assertEq(underlying.balanceOf(address(this)), preDepositBal);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/WITHDRAWAL SANITY CHECK TESTS
    //////////////////////////////////////////////////////////////*/

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

    function testFailWithdrawWithNoBalance() public {
        cvault.withdraw(1e18);
    }

    function testFailDepositWithNoApproval() public {
        cvault.deposit(1e18);
    }

    function testFailWithdrawZero() public {
        cvault.withdraw(0);
    }

    function testFailDepositZero() public {
        cvault.deposit(0);
    }

    /*///////////////////////////////////////////////////////////////
                  BASIC STRATEGY DEPOSIT/WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testAtomicEnterExitSinglePool() public {
        underlying.mint(address(this), 1e18);
        underlying.approve(address(cvault), 1e18);

        // Track balance prior to deposit
        uint256 preDepositBal = underlying.balanceOf(address(this));
        cvault.deposit(1e18);

        // After a successfull Charity Vault Deposit,
        // the vault should contain the amount underlying token
        assertEq(vault.exchangeRate(), 10**vault.decimals());
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - 1e18);

        // The vault should have no balance for this depositor
        assertEq(vault.balanceOf(address(this)), 0);

        // The vault should have mapped the underlying token to the cvault
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);

        // The user should be minted rcvTokens 1:1 to the underlying token
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // Trust Strategy
        vault.trustStrategy(strategy1);

        // Deposit
        vault.depositIntoStrategy(strategy1, 1e18);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // Withdraw
        vault.withdrawFromStrategy(strategy1, 0.5e18);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0.5e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0.5e18);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // Withdraw Again
        vault.withdrawFromStrategy(strategy1, 0.5e18);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);
    }

    function testAtomicEnterExitMultiPool() public {
        underlying.mint(address(this), 1e18);
        underlying.approve(address(cvault), 1e18);

        // Track balance prior to deposit
        uint256 preDepositBal = underlying.balanceOf(address(this));
        cvault.deposit(1e18);

        // After a successfull Charity Vault Deposit,
        // the vault should contain the amount underlying token
        assertEq(vault.exchangeRate(), 10**vault.decimals());
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - 1e18);

        // The vault should have no balance for this depositor
        assertEq(vault.balanceOf(address(this)), 0);

        // The vault should have mapped the underlying token to the cvault
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);

        // The user should be minted rcvTokens 1:1 to the underlying token
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // Trust Strategy
        vault.trustStrategy(strategy1);

        // Deposit only 0.5e18 into strategy 1
        vault.depositIntoStrategy(strategy1, 0.5e18);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0.5e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0.5e18);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // Trust the second strategy
        vault.trustStrategy(strategy2);

        // Deposit the other half of tokens into strategy 2
        vault.depositIntoStrategy(strategy2, 0.5e18);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // Withdraw
        vault.withdrawFromStrategy(strategy1, 0.5e18);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0.5e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0.5e18);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // Withdraw the second half
        vault.withdrawFromStrategy(strategy2, 0.5e18);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 0);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);
    }

    /*///////////////////////////////////////////////////////////////
                         Successful Interest
    //////////////////////////////////////////////////////////////*/

    function testProfitableStrategy() public {
        underlying.mint(address(this), 1.5e18);
        underlying.approve(address(cvault), 1e18);
        
        // Track balance prior to deposit
        uint256 preDepositBal = underlying.balanceOf(address(this));
        cvault.deposit(1e18);

        // After a successfull Charity Vault Deposit,
        // the vault should contain the amount underlying token
        assertEq(vault.exchangeRate(), 10**vault.decimals());
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - 1e18);
        // The vault should have no balance for this depositor
        assertEq(vault.balanceOf(address(this)), 0);
        // The vault should have mapped the underlying token to the cvault
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        // The user should be minted rcvTokens 1:1 to the underlying token
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // ------------------------------------------- //

        // Deposit into Strategy
        vault.trustStrategy(cvStrategy);
        vault.depositIntoStrategy(cvStrategy, 1e18);
        vault.pushToWithdrawalQueue(cvStrategy);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.totalSupply(), 1e18);
        assertEq(vault.balanceOfUnderlying(address(vault)), 0);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // ------------------------------------------- //

        // Mock Earned Interest By Transfering Underlying to the Charity Vault Strategy
        underlying.transfer(address(cvStrategy), 0.5e18);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.totalSupply(), 1e18);
        assertEq(vault.balanceOfUnderlying(address(vault)), 0);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);


        // ------------------------------------------- //

        // Harvest will mint the strategy 0.5e18 underlying tokens //
        vault.harvest(cvStrategy);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1.5e18);
        assertEq(vault.totalHoldings(), 1.05e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(vault)), 0.05e18);
        assertEq(vault.totalSupply(), 1.05e18);
        assertEq(vault.balanceOfUnderlying(address(vault)), 0.05e18);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // ------------------------------------------- //

        // Make sure the harvest delay is checked //
        hevm.warp(block.timestamp + (vault.harvestDelay() / 2));

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1214285714285714285);
        assertEq(vault.totalStrategyHoldings(), 1.5e18);
        assertEq(vault.totalHoldings(), 1.275e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(vault)), 0.05e18);
        assertEq(vault.totalSupply(), 1.05e18);
        assertEq(vault.balanceOfUnderlying(address(vault)), 60714285714285714);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1214285714285714285);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // ------------------------------------------- //

        // Jump to after the harvest delay //
        hevm.warp(block.timestamp + vault.harvestDelay());

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1428571428571428571);
        assertEq(vault.totalStrategyHoldings(), 1.5e18);
        assertEq(vault.totalHoldings(), 1.5e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(vault)), 0.05e18);
        assertEq(vault.totalSupply(), 1.05e18);
        assertEq(vault.balanceOfUnderlying(address(vault)), 71428571428571428);
    
        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1428571428571428571);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // ------------------------------------------- //

        uint256 earnings = 1428571428571428571;

        // Finally, withdraw //
        // cvault.withdraw(0.9e18);

        // Try to extract interest to charity //
        cvault.withdrawInterestToCharity();
        assertEq(underlying.balanceOf(caddress), earnings.fdiv(cfeePercent, BASE_UNIT));

        // Remove 10% from underlying balance //
        // cvault.withdraw(earnings.fmul(9, BASE_UNIT).fdiv(10, BASE_UNIT));

        // // This should have the correct balance
        // assertEq(underlying.balanceOf(address(this)), 1428571428571428571);

        // assertEq(vault.exchangeRate(), 1428571428571428580);
        // assertEq(vault.totalStrategyHoldings(), 70714285714285715);
        // assertEq(vault.totalHoldings(), 71428571428571429);
        // assertEq(vault.totalFloat(), 714285714285714);
        // assertEq(vault.balanceOf(address(vault)), 0.05e18);
        // assertEq(vault.totalSupply(), 0.05e18);
        // assertEq(vault.balanceOfUnderlying(address(vault)), 71428571428571429);

        // // Verify correct Vault and CVault Balances
        // assertEq(vault.balanceOf(address(this)), 0);
        // assertEq(vault.balanceOfUnderlying(address(this)), 0);
        // assertEq(cvault.balanceOf(address(this)), 0);
    }

    function testProfitableStrategyMultipleCharityWithdraws() public {
        underlying.mint(address(this), 1.5e18);
        underlying.approve(address(cvault), 1e18);
        
        // Track balance prior to deposit
        uint256 preDepositBal = underlying.balanceOf(address(this));
        cvault.deposit(1e18);

        // After a successfull Charity Vault Deposit,
        // the vault should contain the amount underlying token
        assertEq(vault.exchangeRate(), 10**vault.decimals());
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(underlying.balanceOf(address(this)), preDepositBal - 1e18);
        // The vault should have no balance for this depositor
        assertEq(vault.balanceOf(address(this)), 0);
        // The vault should have mapped the underlying token to the cvault
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        // The user should be minted rcvTokens 1:1 to the underlying token
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // ------------------------------------------- //

        // Deposit into Strategy
        vault.trustStrategy(cvStrategy);
        vault.depositIntoStrategy(cvStrategy, 1e18);
        vault.pushToWithdrawalQueue(cvStrategy);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.totalSupply(), 1e18);
        assertEq(vault.balanceOfUnderlying(address(vault)), 0);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // Charity Should have nothing //
        assertEq(underlying.balanceOf(caddress), 0);

        // ------------------------------------------- //

        // Mock Earned Interest By Transfering Underlying to the Charity Vault Strategy
        underlying.transfer(address(cvStrategy), 0.5e18);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.totalSupply(), 1e18);
        assertEq(vault.balanceOfUnderlying(address(vault)), 0);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // ------------------------------------------- //

        // Try to extract interest to charity //
        // Note: This _shouldn't_ withdraw anything since no harvests occured //
        cvault.withdrawInterestToCharity();
        assertEq(underlying.balanceOf(caddress), 0);

        // ------------------------------------------- //

        // Harvest will mint the strategy 0.5e18 underlying tokens //
        vault.harvest(cvStrategy);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1.5e18);
        assertEq(vault.totalHoldings(), 1.05e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(vault)), 0.05e18);
        assertEq(vault.totalSupply(), 1.05e18);
        assertEq(vault.balanceOfUnderlying(address(vault)), 0.05e18);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // ------------------------------------------- //

        // Try to extract interest to charity //
        cvault.withdrawInterestToCharity();
        assertEq(underlying.balanceOf(caddress), 0);

        // ------------------------------------------- //

        // Make sure the harvest delay is checked //
        hevm.warp(block.timestamp + (vault.harvestDelay() / 2));

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1214285714285714285);
        assertEq(vault.totalStrategyHoldings(), 1.5e18);
        assertEq(vault.totalHoldings(), 1.275e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(vault)), 0.05e18);
        assertEq(vault.totalSupply(), 1.05e18);
        assertEq(vault.balanceOfUnderlying(address(vault)), 60714285714285714);

        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1214285714285714285);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // ------------------------------------------- //

        // Try to extract interest to charity //
        cvault.withdrawInterestToCharity();
        assertEq(underlying.balanceOf(caddress), 0);

        // ------------------------------------------- //

        // Jump to after the harvest delay //
        hevm.warp(block.timestamp + vault.harvestDelay());

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1428571428571428571);
        assertEq(vault.totalStrategyHoldings(), 1.5e18);
        assertEq(vault.totalHoldings(), 1.5e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(vault)), 0.05e18);
        assertEq(vault.totalSupply(), 1.05e18);
        assertEq(vault.balanceOfUnderlying(address(vault)), 71428571428571428);
    
        // Verify correct Vault and CVault Balances
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1428571428571428571);
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // ------------------------------------------- //



    }
}
