// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

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
    Vault private immutable VAULT;

    /// @notice The underlying token for the vault.
    /// @dev immutable instead of constant so we can set UNDERLYING in the constructor
    ERC20 public immutable UNDERLYING;

    /// @notice the charity's payable donation address
    /// @dev immutable instead of constant so we can set CHARITY in the constructor
    address payable public immutable CHARITY;

    /// @notice the percent of the earned interest that should be redirected to the charity
    /// @dev immutable instead of constant so we can set BASE_FEE in the constructor
    uint256 public immutable BASE_FEE;

    /// @notice One base unit of the underlying, and hence rvToken.
    /// @dev Will be equal to 10 ** UNDERLYING.decimals() which means
    /// if the token has 18 decimals ONE_WHOLE_UNIT will equal 10**18.
    uint256 public immutable BASE_UNIT;

    uint256 pricePerShareAtLastExtraction;
    uint256 rvTokensEarnedByCharity;
    uint256 rvTokensClaimedByCharity;

    /// @notice Creates a new charity vault based on an underlying token.
    /// @param _UNDERLYING An underlying ERC20 compliant token.
    /// @param _CHARITY The address of the charity
    /// @param _BASE_FEE The percent of earned interest to be routed to the Charity
    /// @param _VAULT The existing/deployed Vault for the respective underlying token
    constructor(
        ERC20 _UNDERLYING,
        address payable _CHARITY,
        uint256 _BASE_FEE,
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
            // Set the CharityVault's owner to the CharityVaultFactory's owner:
            CharityVaultFactory(msg.sender).owner()
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

        // TODO: Once we upgrade to 0.8.9 we can use 10**decimals
        // instead which will save us an external call and SLOAD.
        BASE_UNIT = 10**_UNDERLYING.decimals();

        // ?? We shouldn't ever create a new vault here right ??
        // ?? Vaults should already exist ??
        // vault = new Vault(_underlying);

        // TODO: Do we need a BASE_UNIT... prolly
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

    /// @notice Emitted when we receive an ether transfer
    /// @notice Ether transferred to the contract is directed straight to the charity!
    /// @param sender The function caller
    /// @param amount The amount of ether transferred
    event TransparentTransfer(address indexed sender, uint256 amount);

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
            VAULT.BASE_UNIT()
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
