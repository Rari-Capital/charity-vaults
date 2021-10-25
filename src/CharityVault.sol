// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.9;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {Auth} from "solmate/auth/Auth.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Vault} from "vaults/Vault.sol";

import {CharityVaultFactory} from "./CharityVaultFactory.sol";

/// @title Fuse Charity Vault (fcvToken)
/// @author Transmissions11, JetJadeja, Andreas Bigger, Nicolas Neven, Adam Egyed
/// @notice Yield bearing token that enables users to swap
/// their underlying asset to instantly begin earning yield
/// where a percent of the earned interest is sent to charity.
contract CharityVault is ERC20, Auth {
    using SafeERC20 for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev we need to compose a Vault here because the Vault functions are external
    /// @dev which are not able to be overridden since that requires public virtual specifiers
    /// @dev immutable instead of constant so we can set VAULT in the constructor
    // solhint-disable-next-line var-name-mixedcase
    Vault private immutable VAULT;

    /// @notice The underlying token for the vault.
    /// @dev immutable instead of constant so we can set UNDERLYING in the constructor
    // solhint-disable-next-line var-name-mixedcase
    ERC20 public immutable UNDERLYING;

    /// @notice the charity's payable donation address
    /// @dev immutable instead of constant so we can set CHARITY in the constructor
    // solhint-disable-next-line var-name-mixedcase
    address payable public immutable CHARITY;

    /// @notice the percent of the earned interest that should be redirected to the charity
    /// @dev immutable instead of constant so we can set BASE_FEE in the constructor
    // solhint-disable-next-line var-name-mixedcase
    uint256 public immutable BASE_FEE;

    /// @notice One base unit of the underlying, and hence rvToken.
    /// @dev Will be equal to 10 ** UNDERLYING.decimals() which means
    /// if the token has 18 decimals ONE_WHOLE_UNIT will equal 10**18.
    // solhint-disable-next-line var-name-mixedcase
    uint256 public immutable BASE_UNIT;

    /// @notice Price per share of rvTokens earned at the last extraction
    uint256 private pricePerShareAtLastExtraction;

    /// @notice accumulated rvTokens earned by the Charity
    uint256 private rvTokensEarnedByCharity;

    /// @notice rvTokens claimed by the Charity
    uint256 private rvTokensClaimedByCharity;

    /// @notice Creates a new charity vault based on an underlying token.
    /// @param _UNDERLYING An underlying ERC20 compliant token.
    /// @param _CHARITY The address of the charity
    /// @param _BASE_FEE The percent of earned interest to be routed to the Charity
    /// @param _VAULT The existing/deployed Vault for the respective underlying token
    constructor(
        // solhint-disable-next-line var-name-mixedcase
        ERC20 _UNDERLYING,
        // solhint-disable-next-line var-name-mixedcase
        address payable _CHARITY,
        // solhint-disable-next-line var-name-mixedcase
        uint256 _BASE_FEE,
        // solhint-disable-next-line var-name-mixedcase
        Vault _VAULT
    )
        ERC20(
            // ex: Rari DAI Charity Vault
            string(
                abi.encodePacked("Rari ", _UNDERLYING.name(), " Charity Vault")
            ),
            // ex: rcvDAI
            string(abi.encodePacked("rcv", _UNDERLYING.symbol())),
            // ex: 18
            _UNDERLYING.decimals()
        )
        Auth(
            // Sets the CharityVault's owner, authority to the CharityVaultFactory's owner, authority
            CharityVaultFactory(msg.sender).owner(), CharityVaultFactory(msg.sender).authority()
        )
    {
        // Enforce BASE_FEE
        require(
            _BASE_FEE >= 0 && _BASE_FEE <= 100,
            "Fee Percent fails to meet [0, 100] bounds constraint."
        );

        // Define our immutables
        UNDERLYING = _UNDERLYING;
        CHARITY = _CHARITY;
        BASE_FEE = _BASE_FEE;
        VAULT = _VAULT;

        BASE_UNIT = 10**decimals;
    }

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after a successful deposit.
    /// @param user The address of the account that deposited into the vault.
    /// @param underlyingAmount The amount of underlying tokens that were deposited.
    event DepositCV(address indexed user, uint256 underlyingAmount);

    /// @notice Emitted after a successful user withdrawal.
    /// @param user The address of the account that withdrew from the vault.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event WithdrawCV(address indexed user, uint256 underlyingAmount);

    /// @notice Emitted when a Charity successfully withdraws their fee percent of earned interest.
    /// @param charity the address of the charity that withdrew - used primarily for indexing
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event CharityWithdrawCV(address indexed charity, uint256 underlyingAmount);

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit the vault's underlying token to mint rcvTokens.
    /// @param underlyingAmount The amount of the underlying token to deposit.
    function deposit(uint256 underlyingAmount) external {
        // We don't allow depositing 0 to prevent emitting a useless event.
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Extract interest to charity
        extractInterestToCharity();

        // Determine the equivalent amount of rvTokens that will be minted to this charity vault.
        uint256 rvTokensToMint = underlyingAmount.fdiv(
            VAULT.exchangeRate(),
            BASE_UNIT
        );
        _mint(
            msg.sender,
            rvTokensToMint.fdiv(rcvRvExchangeRateAtLastExtraction(), BASE_UNIT)
        );
        emit DepositCV(msg.sender, underlyingAmount);

        // Transfer in UNDERLYING tokens from the sender to the vault
        UNDERLYING.safeTransferFrom(
            msg.sender,
            address(this),
            underlyingAmount
        );

        // Deposit to the VAULT
        VAULT.deposit(underlyingAmount);
    }

    // Returns the total holdings of rvTokens at the time of the last extraction.
    function rvTokensOwnedByUsersAtLastExtraction()
        internal
        view
        returns (uint256)
    {
        return (VAULT.balanceOf(address(this)) -
            (rvTokensEarnedByCharity - rvTokensClaimedByCharity));
    }

    /// @dev Extracts and withdraws unclaimed interest earned by charity.
    function withdrawInterestToCharity() external {
        extractInterestToCharity();
        uint256 rvTokensToClaim = rvTokensEarnedByCharity -
            rvTokensClaimedByCharity;
        rvTokensClaimedByCharity = rvTokensEarnedByCharity;
        VAULT.transfer(CHARITY, rvTokensToClaim);
    }

    /// @notice returns the rvTokens owned by a user
    function rvTokensOwnedByUser(address user) public view returns (uint256) {
        uint256 pricePerShareNow = VAULT.exchangeRate();

        uint256 underlyingEarnedByUsersSinceLastExtraction = (VAULT.balanceOf(
            address(this)
        ) - (rvTokensEarnedByCharity - rvTokensClaimedByCharity)) *
            (pricePerShareNow - pricePerShareAtLastExtraction);
        uint256 underlyingToUser = ((underlyingEarnedByUsersSinceLastExtraction *
                this.balanceOf(user)) / totalSupply) / 100;
        uint256 rcvTokensToUser = underlyingToUser.fdiv(
            pricePerShareNow,
            // recalculate decimals to navigate around BASE_UNIT being internal
            10**VAULT.decimals()
        );

        return rcvTokensToUser;
    }

    /// @notice Withdraws a user's interest earned from the vault.
    /// @param withdrawalAmount The amount of the underlying token to withdraw.
    function withdraw(uint256 withdrawalAmount) external {
        // We don't allow withdrawing 0 to prevent emitting a useless event.
        require(withdrawalAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // First extract interest to charity
        extractInterestToCharity();

        // Determine the equivalent amount of rcvTokens and burn them.
        // This will revert if the user does not have enough rcvTokens.
        _burn(
            msg.sender,
            withdrawalAmount.fdiv(VAULT.exchangeRate(), BASE_UNIT)
        );

        uint256 rvTokensToUser = rvTokensOwnedByUser(msg.sender);

        require(rvTokensToUser >= withdrawalAmount, "INSUFFICIENT_FUNDS");

        // Try to transfer balance to msg.sender
        VAULT.transfer(msg.sender, withdrawalAmount);
    }

    /*///////////////////////////////////////////////////////////////
                        VAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Do this before user deposits, user withdrawals, and charity withdrawals.
    function extractInterestToCharity() internal {
        uint256 pricePerShareNow = VAULT.exchangeRate();

        if (pricePerShareAtLastExtraction == 0) {
            pricePerShareAtLastExtraction = pricePerShareNow;
            return;
        }

        uint256 underlyingEarnedByUsersSinceLastExtraction = (VAULT.balanceOf(
            address(this)
        ) - (rvTokensEarnedByCharity - rvTokensClaimedByCharity)) *
            (pricePerShareNow - pricePerShareAtLastExtraction);
        uint256 underlyingToCharity = (underlyingEarnedByUsersSinceLastExtraction *
                BASE_FEE) / 100;
        uint256 rvTokensToCharity = underlyingToCharity.fdiv(
            pricePerShareNow,
            // recalculate decimals to navigate around BASE_UNIT being internal
            10**VAULT.decimals()
        );
        pricePerShareAtLastExtraction = pricePerShareNow;
        rvTokensEarnedByCharity += rvTokensToCharity;
    }

    // Returns the exchange rate of rcvTokens in terms of rvTokens since the last extraction.
    function rcvRvExchangeRateAtLastExtraction()
        internal
        view
        returns (uint256)
    {
        // If there are no rvTokens in circulation, return an exchange rate of 1:1.
        if (totalSupply == 0) return BASE_UNIT;

        // TODO: Optimize double SLOAD of totalSupply here?
        // Calculate the exchange rate by diving the total holdings by the rvToken supply.
        return
            rvTokensOwnedByUsersAtLastExtraction().fdiv(totalSupply, BASE_UNIT);
    }
}
