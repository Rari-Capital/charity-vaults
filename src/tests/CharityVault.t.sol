// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import {Authority} from "solmate/auth/Auth.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Vault} from "vaults/Vault.sol";
import {VaultFactory} from "vaults/VaultFactory.sol";
import {MockERC20Strategy} from "vaults/test/mocks/MockERC20Strategy.sol";
import {Strategy} from "vaults/interfaces/Strategy.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {CharityVaultMockStrategy} from "./mocks/CharityVaultMockStrategy.sol";
import {CharityVault} from "../CharityVault.sol";
import {CharityVaultFactory} from "../CharityVaultFactory.sol";

contract CharityVaultTest is DSTestPlus {
    using FixedPointMathLib for uint256;

    MockERC20 public underlying;

    /// @dev Vault Logic
    Vault public vault;
    VaultFactory public vaultFactory;
    MockERC20Strategy public strategy1;
    MockERC20Strategy public strategy2;
    CharityVaultMockStrategy public cvStrategy;

    /// @dev CharityVault Logic
    CharityVault public cvault;
    CharityVaultFactory public cvaultFactory;
    // address payable public immutable caddress = payable(address(0));
    address payable public caddress;
    uint256 public immutable cfeePercent = 10;
    uint256 public nonce = 1;

    /// @dev BASE_UNIT variable used in the contract
    // solhint-disable-next-line var-name-mixedcase
    uint256 public immutable BASE_UNIT = 10**18;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vaultFactory = new VaultFactory(address(this), Authority(address(0)));
        vault = vaultFactory.deployVault(underlying);

        vault.setFeePercent(0.1e18);
        vault.setHarvestDelay(6 hours);
        vault.setHarvestWindow(5 minutes);
        vault.setTargetFloatPercent(0.01e18);

        vault.initialize();

        strategy1 = new MockERC20Strategy(underlying);
        strategy2 = new MockERC20Strategy(underlying);
        cvStrategy = new CharityVaultMockStrategy(underlying);

        // Create a mock strategy to act as the charity //
        MockERC20Strategy mockCharity = new MockERC20Strategy(
            new MockERC20("Random Token", "RNDM", 18)
        );
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
        Vault _vault = new VaultFactory(address(this), Authority(address(0)))
            .deployVault(_underlying);

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

    /// @notice Tests all parameters after a deposit
    /// @param userBalance A fuzzed input for the amount the user deposits
    function testDepositParams(uint256 userBalance) public {
        // Skip test if the deposit is greater than the max uint256
        if (userBalance > 1e18 || userBalance == 0) {
            return;
        }

        underlying.mint(address(this), userBalance);
        underlying.approve(address(cvault), userBalance);

        // Initially the exchange rate should be the BASE_UNIT
        assertEq(cvault.rcvRvExchangeRate(), BASE_UNIT);

        // Track balance prior to deposit
        uint256 preDepositBal = underlying.balanceOf(address(this));
        cvault.deposit(userBalance);

        // After a successfull Charity Vault Deposit,
        // the vault should contain the amount underlying token
        assertEq(vault.exchangeRate(), BASE_UNIT);
        assertEq(vault.totalHoldings(), userBalance);
        assertEq(vault.totalFloat(), userBalance);
        assertEq(
            underlying.balanceOf(address(this)),
            preDepositBal - userBalance
        );

        // The vault should have no balance for this depositor
        assertEq(vault.balanceOf(address(this)), 0);

        // The vault should have mapped the underlying token to the cvault
        assertEq(vault.balanceOfUnderlying(address(cvault)), userBalance);

        // The user should be minted rcvTokens 1:1 to the underlying token
        assertEq(cvault.balanceOf(address(this)), userBalance);

        // After a deposit, the exchange rate should be the rvTokens owned
        // by users at last extraction divided by the total supply.
        assertEq(cvault.rcvRvExchangeRate(), BASE_UNIT);
    }

    /// @notice Tests Deposit params with a static input
    function testDepositParamsStatic() public {
        testDepositParams(100);
    }

    /// @notice Tests depositing twice
    /// @param userBalance A fuzzed input for the amount the user deposits
    function testMultiDeposits(uint256 userBalance) public {
        // Skip test if the deposit is greater than the max uint256
        if (userBalance > 1e18 || userBalance == 0) {
            return;
        }

        underlying.mint(address(this), userBalance);
        underlying.approve(address(cvault), userBalance);

        // Initially the exchange rate should be the BASE_UNIT
        assertEq(cvault.rcvRvExchangeRate(), BASE_UNIT);

        // Track balance prior to deposit
        uint256 preDepositBal = underlying.balanceOf(address(this));
        cvault.deposit(userBalance);

        // Vault Sanity Checks
        assertEq(vault.exchangeRate(), BASE_UNIT);
        assertEq(vault.totalHoldings(), userBalance);
        assertEq(vault.totalFloat(), userBalance);
        assertEq(
            underlying.balanceOf(address(this)),
            preDepositBal - userBalance
        );
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), userBalance);

        // The user should be minted rcvTokens 1:1 to the underlying token
        assertEq(cvault.balanceOf(address(this)), userBalance);

        // After a deposit, the exchange rate should be the rvTokens owned
        // by users at last extraction divided by the total supply.
        assertEq(cvault.rcvRvExchangeRate(), BASE_UNIT);

        // Now, deposit again
        underlying.mint(address(this), userBalance);
        underlying.approve(address(cvault), userBalance);
        preDepositBal += userBalance;
        cvault.deposit(userBalance);

        // Vault Sanity Checks
        assertEq(vault.exchangeRate(), BASE_UNIT);
        assertEq(vault.totalHoldings(), preDepositBal);
        assertEq(vault.totalFloat(), preDepositBal);
        assertEq(underlying.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), preDepositBal);
    }

    /// @notice Tests Multi Deposits with a static input
    function testMultiDepositsStatic() public {
        testMultiDeposits(100);
    }

    /// @notice Tests depositing and withdrawing into the Charity Vault with Small numbers
    /// @param userBalance A fuzzed input for the amount the user deposits
    function testAtomicDepositWithdrawSmallNumbers(uint256 userBalance) public {
        // Skip test if the deposit is greater than the max uint256
        if (userBalance > 1e18 || userBalance == 0) {
            return;
        }

        underlying.mint(address(this), userBalance);
        underlying.approve(address(cvault), userBalance);

        // Track balance prior to deposit
        uint256 preDepositBal = underlying.balanceOf(address(this));
        cvault.deposit(userBalance);

        // After a successfull Charity Vault Deposit,
        // the vault should contain the amount underlying token
        assertEq(vault.exchangeRate(), BASE_UNIT);
        assertEq(vault.totalHoldings(), userBalance);
        assertEq(vault.totalFloat(), userBalance);
        assertEq(
            underlying.balanceOf(address(this)),
            preDepositBal - userBalance
        );

        // The vault should have no balance for this depositor
        assertEq(vault.balanceOf(address(this)), 0);

        // The vault should have mapped the underlying token to the cvault
        assertEq(vault.balanceOfUnderlying(address(cvault)), userBalance);

        // The user should be minted rcvTokens 1:1 to the underlying token
        assertEq(cvault.balanceOf(address(this)), userBalance);

        cvault.withdraw(userBalance);

        // Vault Balances
        assertEq(vault.exchangeRate(), BASE_UNIT);
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

    /// @notice Tests multiple deposits and withdrawals
    /// @notice Pattern: deposit, deposit, withdraw, deposit, withdraw, withdraw
    function testMultipleDepositsAndWithdrawals() public {
        underlying.mint(address(this), 1e18);

        // Deposit the first half
        underlying.approve(address(cvault), 0.5e18);
        cvault.deposit(0.5e18);
        assertEq(underlying.balanceOf(address(this)), 0.5e18);
        assertEq(underlying.balanceOf(address(cvault)), 0);
        assertEq(underlying.balanceOf(address(vault)), 0.5e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(cvault)), 0.5e18);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 0.5e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 0);
        assertEq(cvault.balanceOf(address(this)), 0.5e18);
        assertEq(cvault.balanceOf(address(vault)), 0);

        // Deposit the second half
        underlying.approve(address(cvault), 0.5e18);
        cvault.deposit(0.5e18);
        assertEq(underlying.balanceOf(address(this)), 0);
        assertEq(underlying.balanceOf(address(cvault)), 0);
        assertEq(underlying.balanceOf(address(vault)), 1e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(cvault)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 0);
        assertEq(cvault.balanceOf(address(this)), 1e18);
        assertEq(cvault.balanceOf(address(vault)), 0);

        // Withdraw the second half
        cvault.withdraw(0.5e18);
        assertEq(underlying.balanceOf(address(this)), 0.5e18);
        assertEq(underlying.balanceOf(address(cvault)), 0);
        assertEq(underlying.balanceOf(address(vault)), 0.5e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(cvault)), 0.5e18);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 0.5e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 0);
        assertEq(cvault.balanceOf(address(this)), 0.5e18);
        assertEq(cvault.balanceOf(address(vault)), 0);

        // Deposit the second half
        underlying.approve(address(cvault), 0.5e18);
        cvault.deposit(0.5e18);
        assertEq(underlying.balanceOf(address(this)), 0);
        assertEq(underlying.balanceOf(address(cvault)), 0);
        assertEq(underlying.balanceOf(address(vault)), 1e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(cvault)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 0);
        assertEq(cvault.balanceOf(address(this)), 1e18);
        assertEq(cvault.balanceOf(address(vault)), 0);

        // Withdraw the second half
        cvault.withdraw(0.5e18);
        assertEq(underlying.balanceOf(address(this)), 0.5e18);
        assertEq(underlying.balanceOf(address(cvault)), 0);
        assertEq(underlying.balanceOf(address(vault)), 0.5e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(cvault)), 0.5e18);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 0.5e18);
        assertEq(vault.balanceOfUnderlying(address(this)), 0);
        assertEq(cvault.balanceOf(address(this)), 0.5e18);
        assertEq(cvault.balanceOf(address(vault)), 0);

        // Withdraw the first half
        cvault.withdraw(0.5e18);
        assertEq(underlying.balanceOf(address(this)), 1e18);
        assertEq(underlying.balanceOf(address(cvault)), 0);
        assertEq(underlying.balanceOf(address(vault)), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(address(cvault)), 0);
        assertEq(vault.balanceOfUnderlying(address(cvault)), 0);
        assertEq(vault.balanceOfUnderlying(address(this)), 0);
        assertEq(cvault.balanceOf(address(this)), 0);
        assertEq(cvault.balanceOf(address(vault)), 0);
    }

    /*///////////////////////////////////////////////////////////////
                DEPOSIT/WITHDRAWAL SANITY CHECK TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test Charity Withdrawal from CharityVault
    function testCharityVaultWithdrawal() public {
        cvault.withdrawInterestToCharity();
    }

    /// @notice Test Charity Withdrawal from CharityVault with a Deposit
    function testCharityVaultWithdrawalWithDeposit() public {
        // Deposit to inflate the totalSupply of the Vault
        underlying.mint(address(this), 1e18);
        underlying.approve(address(cvault), 1e18);
        cvault.deposit(1e18);

        // Sanity Checks
        assertEq(vault.exchangeRate(), 10**vault.decimals());
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(vault.totalSupply(), 1e18);
        assertEq(cvault.totalSupply(), 1e18);

        // Now Withdraw
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
        cvault.deposit(1e18);

        // Sanity Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(underlying.balanceOf(address(this)), 0.5e18);
        // The vault should have no balance for this depositor
        assertEq(vault.balanceOf(address(this)), 0);
        // The vault should have mapped the underlying token to the cvault
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        // The user should be minted rcvTokens 1:1 to the underlying token
        assertEq(cvault.balanceOf(address(this)), 1e18);

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

        // Mock Earned Interest By Transfering Underlying to the Charity Vault Strategy
        underlying.transfer(address(cvStrategy), 0.5e18);

        // Harvest will mint the strategy 0.5e18 underlying tokens //
        Strategy[] memory strategiesToHarvest = new Strategy[](1);
        strategiesToHarvest[0] = cvStrategy;
        vault.harvest(strategiesToHarvest);

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
        assertEq(
            vault.balanceOfUnderlying(address(cvault)),
            1428571428571428571
        );
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // Validate balances before withdrawal //
        assertEq(
            cvault.balanceOfUnderlying(address(this)),
            1385714285714285715
        );
        assertEq(underlying.balanceOf(address(this)), 0);

        // Finally, withdraw //
        cvault.withdraw(1385714285714285715);

        // Validate balances after withdrawal //
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(cvault.balanceOf(address(this)), 2);
        assertEq(cvault.balanceOfUnderlying(address(this)), 1);
        assertEq(underlying.balanceOf(address(this)), 1385714285714285715);

        // Try to extract interest to charity //
        cvault.withdrawInterestToCharity();
        assertEq(underlying.balanceOf(caddress), 42857142857142855);
    }

    function testProfitableStrategyMultipleCharityWithdraws() public {
        underlying.mint(address(this), 2e18);
        underlying.approve(address(cvault), 1e18);
        cvault.deposit(1e18);

        // Sanity Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalHoldings(), 1e18);
        assertEq(vault.totalFloat(), 1e18);
        assertEq(underlying.balanceOf(address(this)), 1e18);
        // The vault should have no balance for this depositor
        assertEq(vault.balanceOf(address(this)), 0);
        // The vault should have mapped the underlying token to the cvault
        assertEq(vault.balanceOfUnderlying(address(cvault)), 1e18);
        // The user should be minted rcvTokens 1:1 to the underlying token
        assertEq(cvault.balanceOf(address(this)), 1e18);

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

        // Mock Earned Interest By Transfering Underlying to the Charity Vault Strategy
        underlying.transfer(address(cvStrategy), 0.5e18);

        // Harvest will mint the strategy 0.5e18 underlying tokens //
        Strategy[] memory strategiesToHarvest = new Strategy[](1);
        strategiesToHarvest[0] = cvStrategy;
        vault.harvest(strategiesToHarvest);

        // Sanity Vault Checks
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.totalStrategyHoldings(), 1.5e18);
        assertEq(vault.totalHoldings(), 1.05e18);
        assertEq(vault.totalFloat(), 0);
        assertEq(vault.balanceOf(address(vault)), 0.05e18);
        assertEq(vault.totalSupply(), 1.05e18);
        assertEq(vault.balanceOfUnderlying(address(vault)), 0.05e18);

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
        assertEq(
            vault.balanceOfUnderlying(address(cvault)),
            1428571428571428571
        );
        assertEq(cvault.balanceOf(address(this)), 1e18);

        // Validate User Balances //
        assertEq(
            cvault.balanceOfUnderlying(address(this)),
            1385714285714285715
        );
        assertEq(underlying.balanceOf(address(this)), 0.5e18);

        // Extract interest to charity //
        cvault.withdrawInterestToCharity();
        assertEq(underlying.balanceOf(caddress), 42857142857142855);

        // Mock More Earned Interest
        underlying.transfer(address(cvStrategy), 0.5e18);

        // Apply to the strategy
        vault.harvest(strategiesToHarvest);
        assertEq(vault.totalStrategyHoldings(), 1942571428571428573);
        assertEq(vault.totalFloat(), 14571428571428571);

        // Jump to after the harvest delay //
        hevm.warp(block.timestamp + vault.harvestDelay());

        // Validate balances before withdrawal //
        assertEq(
            cvault.balanceOfUnderlying(address(this)),
            1758083953960731214
        );
        assertEq(underlying.balanceOf(address(this)), 0);

        // Withdraw
        cvault.withdraw(1758083953960731214);

        // Validate balances after withdrawal //
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(cvault.balanceOf(address(this)), 2);
        assertEq(cvault.balanceOfUnderlying(address(this)), 3);
        assertEq(underlying.balanceOf(address(this)), 1758083953960731214);

        // Extract interest to charity //
        cvault.withdrawInterestToCharity();
        assertEq(underlying.balanceOf(caddress), 84231550440081241);

        // The Vault should now be empty
        assertEq(vault.balanceOf(address(cvault)), 2);
        assertEq(vault.totalSupply(), 85000000000000001);
        assertEq(cvault.totalSupply(), 1);
    }
}
