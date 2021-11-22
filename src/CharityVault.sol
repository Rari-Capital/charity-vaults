// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import {Auth} from "solmate/auth/Auth.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Vault} from "vaults/Vault.sol";

import {CharityVaultFactory} from "./CharityVaultFactory.sol";

/// @title Fuse Charity Vault (fcvToken)
/// @author Transmissions11, JetJadeja, Andreas Bigger, Nicolas Neven, Adam Egyed, David Lucid
/// @notice Yield bearing token that enables users to swap
/// their underlying asset to instantly begin earning yield
/// where a percent of the earned interest is sent to charity.
contract CharityVault is ERC20, Auth {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                                State
    //////////////////////////////////////////////////////////////*/

    /// @dev we need to compose a Vault here because the Vault functions are external
    /// @dev which are not able to be overridden since that requires public virtual specifiers
    /// @dev immutable instead of constant so we can set VAULT in the constructor
    // solhint-disable-next-line var-name-mixedcase
    Vault public immutable VAULT;

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

    /// @notice Price per share of rvTokens at the last extraction
    uint256 private pricePerShareAtLastExtraction;

    /// @notice Total rvTokens earned by the Charity at the last extraction
    uint256 private rvTokensEarnedByCharity;

    /// @notice Total rvTokens claimed by the Charity
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
            CharityVaultFactory(msg.sender).owner(),
            CharityVaultFactory(msg.sender).authority()
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
    /// @param vaultExchangeRate The current Vault exchange rate.
    /// @param cvaultExchangeRate The current Vault exchange rate.
    event DepositCV(
        address indexed user,
        uint256 underlyingAmount,
        uint256 vaultExchangeRate,
        uint256 cvaultExchangeRate
    );

    /// @notice Emitted after a successful user withdrawal.
    /// @param user The address of the account that withdrew from the vault.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    /// @param vaultExchangeRate The current Vault exchange rate.
    /// @param cvaultExchangeRate The current Vault exchange rate.
    event WithdrawCV(
        address indexed user,
        uint256 underlyingAmount,
        uint256 vaultExchangeRate,
        uint256 cvaultExchangeRate
    );

    /// @notice Emitted when a Charity successfully withdraws their fee percent of earned interest.
    /// @param charity the address of the charity that withdrew - used primarily for indexing
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    /// @param vaultExchangeRate The current Vault exchange rate.
    /// @param cvaultExchangeRate The current Vault exchange rate.
    event CharityWithdrawCV(
        address indexed charity,
        uint256 underlyingAmount,
        uint256 vaultExchangeRate,
        uint256 cvaultExchangeRate
    );

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT AND WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit the vault's underlying token to mint rcvTokens
    /// @param underlyingAmount The amount of the underlying token to deposit
    function deposit(uint256 underlyingAmount) external {
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Extract interest to charity
        extractInterestToCharity();

        // Fix exchange rates
        uint256 vaultEr = VAULT.exchangeRate();
        uint256 cVaultEr = rcvRvExchangeRate();

        // Determine the equivalent amount of rvTokens that will be minted to this charity vault.
        uint256 rvTokensToMint = underlyingAmount.fdiv(vaultEr, BASE_UNIT);
        _mint(msg.sender, rvTokensToMint.fdiv(cVaultEr, BASE_UNIT));
        emit DepositCV(msg.sender, underlyingAmount, vaultEr, cVaultEr);

        // Transfer in UNDERLYING tokens from the sender to the vault
        UNDERLYING.safeApprove(address(VAULT), underlyingAmount);
        UNDERLYING.safeTransferFrom(
            msg.sender,
            address(this),
            underlyingAmount
        );

        // Deposit to the VAULT
        VAULT.deposit(underlyingAmount);
    }

    /// @notice Extracts and withdraws unclaimed interest earned by charity
    function withdrawInterestToCharity() external {
        // Extract interest to charity
        extractInterestToCharity();

        // Update claimed rvTokens
        uint256 rvTokensToClaim = rvTokensEarnedByCharity -
            rvTokensClaimedByCharity;
        rvTokensClaimedByCharity = rvTokensEarnedByCharity;

        // Fix exchange rates
        uint256 vaultEr = VAULT.exchangeRate();
        uint256 cVaultEr = rcvRvExchangeRate();

        if (rvTokensToClaim <= 0) return;
        
        uint256 withdrawUnderlyingAmount = rvTokensToClaim.fmul(
            vaultEr,
            BASE_UNIT
        );

        /// Redeem and transfer
        VAULT.redeem(rvTokensToClaim);
        UNDERLYING.safeTransfer(CHARITY, withdrawUnderlyingAmount);
        
        // Pessimistic Event Emission
        emit CharityWithdrawCV(
            msg.sender,
            withdrawUnderlyingAmount,
            vaultEr,
            cVaultEr
        );
    }

    /// @notice Withdraws a user's interest earned from the vault.
    /// @param withdrawalAmount The amount of the underlying token to withdraw.
    function withdraw(uint256 withdrawalAmount) external {
        require(withdrawalAmount != 0, "AMOUNT_CANNOT_BE_ZERO");
        require(
            balanceOfUnderlying(msg.sender) >= withdrawalAmount,
            "INSUFFICIENT_BALANCE"
        );

        // Extract interest to charity
        extractInterestToCharity();

        // Fix Exchange Rates
        uint256 vaultEr = VAULT.exchangeRate();
        uint256 cVaultEr = rcvRvExchangeRate();

        // Calculate Token Amounts
        uint256 amountRvTokensToWithdraw = withdrawalAmount.fdiv(
            vaultEr,
            BASE_UNIT
        );
        uint256 amountRcvTokensToWithdraw = amountRvTokensToWithdraw.fdiv(
            cVaultEr,
            BASE_UNIT
        );

        // This will revert if the user does not have enough rcvTokens.
        _burn(msg.sender, amountRcvTokensToWithdraw);

        // Try to transfer balance to msg.sender
        VAULT.withdraw(withdrawalAmount);
        UNDERLYING.safeTransfer(msg.sender, withdrawalAmount);

        // Pessimistic Event Emition
        emit WithdrawCV(msg.sender, withdrawalAmount, vaultEr, cVaultEr);
    }

    /*///////////////////////////////////////////////////////////////
                        CHARITY VAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Do this before user deposits, user withdrawals, and charity withdrawals.
    function extractInterestToCharity() internal {
        uint256 pricePerShareNow = VAULT.exchangeRate();

        if (pricePerShareAtLastExtraction == 0) {
            pricePerShareAtLastExtraction = pricePerShareNow;
            return;
        }

        rvTokensEarnedByCharity += rvTokensToCharitySinceLastExtraction(
            pricePerShareNow
        );
        pricePerShareAtLastExtraction = pricePerShareNow;
    }

    /// @notice Calculates the amount of rvTokens to extract to the charity since the last extraction
    /// @dev Pass in a pre-fetched price per share to prevent contentions
    /// @param pricePerShareNow The vault exchange rate
    /// @return The amount of rvTokens earned by a the charity since the last extraction as a uint256
    function rvTokensToCharitySinceLastExtraction(uint256 pricePerShareNow)
        internal
        view
        returns (uint256)
    {
        // If pricePerShareNow <= pricePerShareAtLastExtraction, return 0
        if (pricePerShareNow <= pricePerShareAtLastExtraction) return 0;

        // Get amount of underlying tokens earned by vault users since last extraction
        // (before subtracting the quantity going to charity)
        uint256 underlyingEarnedByUsersSinceLastExtraction = rvTokensOwnedByUsersAtLastExtraction()
                .fmul(
                    (pricePerShareNow - pricePerShareAtLastExtraction),
                    BASE_UNIT
                );

        // Get the amount of underlying to be directed to charity
        /// @dev need to divide by 100 since BASE_FEE is a percent
        /// @dev represented as whole numbers (i.e. 0.10 or 10% is a BASE_FEE=10)
        uint256 underlyingToCharity = (underlyingEarnedByUsersSinceLastExtraction *
                BASE_FEE) / 100;

        underlyingToCharity += (rvTokensEarnedByCharity -
            rvTokensClaimedByCharity).fmul(
                (pricePerShareNow - pricePerShareAtLastExtraction),
                BASE_UNIT
            );

        return underlyingToCharity.fdiv(pricePerShareNow, VAULT.BASE_UNIT());
    }

    /// @notice Returns the total holdings of rvTokens at the time of the last extraction.
    /// @return The amount of rvTokens owned by the vault at the last extraction as a uint256
    function rvTokensOwnedByUsersAtLastExtraction()
        internal
        view
        returns (uint256)
    {
        return (VAULT.balanceOf(address(this)) -
            (rvTokensEarnedByCharity - rvTokensClaimedByCharity));
    }

    /// @notice Calculates the total interest earned by the Charity
    /// @return the total interest earned in rvTokens
    function getRVTokensEarnedByCharity() internal view returns (uint256) {
        uint256 pricePerShareNow = VAULT.exchangeRate();
        if (pricePerShareAtLastExtraction == 0) return 0;
        return
            rvTokensEarnedByCharity +
            rvTokensToCharitySinceLastExtraction(pricePerShareNow);
    }

    /// @notice Calculates the amount of rvTokens earned and not claimed by the charity
    /// @return The number of earned rvTokens
    function getRVTokensUnclaimedByCharity() internal view returns (uint256) {
        // Sums the rvTokens earned plus additional calculated
        // earnings (since the last extraction), minus total claimed
        return getRVTokensEarnedByCharity() - rvTokensClaimedByCharity;
    }

    /// @notice Returns the exchange rate of rcvTokens in terms of rvTokens since the last extraction.
    function rcvRvExchangeRate() public view returns (uint256) {
        // Get the total supply of rvTokens.
        uint256 rcvTokenSupply = totalSupply;

        // If there are no rcvTokens in circulation, return an exchange rate of 1:1.
        if (rcvTokenSupply == 0) return BASE_UNIT;

        // Get rvTokens currently owned by users
        uint256 rvTokensOwnedByUsers = VAULT.balanceOf(address(this)) -
            getRVTokensUnclaimedByCharity();

        // Calculate the exchange rate by diving the total holdings by the rcvToken supply.
        return rvTokensOwnedByUsers.fdiv(rcvTokenSupply, BASE_UNIT);
    }

    /// @notice Returns the exchange rate of rcvTokens to underlying
    function exchangeRate() public view returns (uint256) {
        return rcvRvExchangeRate().fmul(VAULT.exchangeRate(), BASE_UNIT);
    }

    /// @notice Returns the rvTokens owned by a user
    /// @param user The address of the user to get the rvToken balance
    /// @return The number of rvTokens owned as a uint256
    function balanceOfRVTokens(address user) external view returns (uint256) {
        return balanceOf[user].fmul(rcvRvExchangeRate(), BASE_UNIT);
    }

    /// @notice Returns a user's Vault balance in underlying tokens.
    /// @param user The user to get the underlying balance of.
    /// @return The user's Vault balance in underlying tokens.
    function balanceOfUnderlying(address user) public view returns (uint256) {
        return balanceOf[user].fmul(exchangeRate(), BASE_UNIT);
    }

    /*///////////////////////////////////////////////////////////////
                          RECIEVE ETHER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Required for the CharityVault to receive unwrapped ETH.
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
