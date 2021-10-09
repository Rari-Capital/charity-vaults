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
    /// @dev immutable instead of constant so we can set FEE_PERCENT in the constructor
    uint256 public immutable FEE_PERCENT;

    /// @notice One base unit of the underlying, and hence rvToken.
    /// @dev Will be equal to 10 ** UNDERLYING.decimals() which means
    /// if the token has 18 decimals ONE_WHOLE_UNIT will equal 10**18.
    uint256 public immutable BASE_UNIT;

    /// @notice Creates a new charity vault based on an underlying token.
    /// @param _UNDERLYING An underlying ERC20 compliant token.
    /// @param _CHARITY The address of the charity
    /// @param _FEE_PERCENT The percent of earned interest to be routed to the Charity
    /// @param _VAULT The existing/deployed Vault for the respective underlying token
    constructor(ERC20 _UNDERLYING, address payable _CHARITY, uint256 _FEE_PERCENT, Vault _VAULT)
        ERC20(
            // ex: Rari DAI Charity Vault
            string(abi.encodePacked("Rari ", _UNDERLYING.name(), " Charity Vault")),
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
        // Enforce FEE_PERCENT
        require(_FEE_PERCENT >= 0 && _FEE_PERCENT <= 100, "Fee Percent fails to meet [0, 100] bounds constraint.");

        // Define our immutables
        UNDERLYING = _UNDERLYING;
        CHARITY = _CHARITY;
        FEE_PERCENT = _FEE_PERCENT;
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
    event CharityDeposit(address indexed user, uint256 underlyingAmount);

    /// @notice Emitted after a successful withdrawal.
    /// @param user The address of the account that withdrew from the vault.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event CharityWithdraw(address indexed user, uint256 underlyingAmount);

    /// @notice Emitted when a Charity successfully withdraws their fee percent of earned interest.
    /// @param charity the address of the charity that withdrew - used primarily for indexing
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event DonationWithdraw(address indexed charity, uint256 underlyingAmount);

    /*///////////////////////////////////////////////////////////////
                         USER ACTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit the vault's underlying token to mint rcvTokens.
    /// @param underlyingAmount The amount of the underlying token to deposit.
    function deposit(uint256 underlyingAmount) external {
        // We don't allow depositing 0 to prevent emitting a useless event.
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // ?? Do we need to mint prior or post in case VAULT revert ??

        // Transfer in UNDERLYING tokens from the sender to the vault
        UNDERLYING.safeTransferFrom(msg.sender, address(this), underlyingAmount);

        // Deposit to the VAULT
        VAULT.deposit(underlyingAmount);

        // Determine the equivalent amount of rcvTokens and mint them.
        _mint(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        emit CharityDeposit(msg.sender, underlyingAmount);

    }

    /// @notice Burns rcvTokens and sends underlying tokens to the caller.
    /// @param underlyingAmount The amount of underlying tokens to withdraw
    function withdraw(uint256 underlyingAmount) external {
        // We don't allow withdrawing 0 to prevent emitting a useless event.
        require(underlyingAmount != 0, "AMOUNT_CANNOT_BE_ZERO");

        // Withdraw from the VAULT
        VAULT.withdraw(underlyingAmount);

        // Transfer underlying tokens to the user.
        UNDERLYING.safeTransfer(msg.sender, underlyingAmount);

        // Determine the equivalent amount of rcvTokens and burn them.
        // This will revert if the user does not have enough rcvTokens.
        _burn(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        emit CharityWithdraw(msg.sender, underlyingAmount);




        // If the withdrawal amount is greater than the float, pull tokens from Fuse.
        // if (underlyingAmount > getFloat()) vault.pullIntoFloat(underlyingAmount);

        // TODO: this needs to be updated to include charity withdraw
        // Transfer tokens to the caller.
        UNDERLYING.safeTransfer(msg.sender, underlyingAmount);

    }

    /// @notice Burns rcvTokens and sends underlying tokens to the caller.
    /// @param underlyingAmount The amount of underlying tokens to withdraw.
    function withdrawUnderlying(uint256 underlyingAmount) external {
        // Query the vault's exchange rate.
        uint256 exchangeRate = exchangeRateCurrent();

        // Convert underlying tokens to rcvTokens and then burn them.
        // This can be done by multiplying the underlying tokens by the exchange rate.
        _burn(msg.sender, (exchangeRate * underlyingAmount) / 10**decimals);

        // If the withdrawal amount is greater than the float, pull tokens from Fuse.
        // TODO: how to pull in float?
        // if (getFloat() < underlyingAmount) vault.pullIntoFloat(underlyingAmount);

        // TODO: this needs to be updated to calculate how much use should get
        // Transfer underlying tokens to the sender.
        UNDERLYING.safeTransfer(msg.sender, underlyingAmount);

        emit CharityWithdraw(msg.sender, underlyingAmount);
    }

    // TODO: Charity Withdraw function
    // TODO: this function should only be callable by the charity

    /// @notice Burns rcvTokens and sends underlying tokens to the charity.
    /// @param amount The amount of rcvTokens to redeem for underlying tokens.
    function charityWithdraw(uint256 amount) external {
        // Query the vault's exchange rate.
        uint256 exchangeRate = exchangeRateCurrent();

        // TODO: we have to somehow keep track of how much is owed to the charity vs the user
        // Convert the amount of rcvTokens to underlying tokens.
        // This can be done by multiplying the rcvTokens by the exchange rate.
        uint256 underlyingAmount = ((exchangeRate * amount) / 10**decimals) * (FEE_PERCENT / 100.0);

        // Burn inputed rcvTokens.
        _burn(CHARITY, amount);

        // If the withdrawal amount is greater than the float, pull tokens from Fuse.
        // if (underlyingAmount > getFloat()) vault.pullIntoFloat(underlyingAmount);

        // TODO: this needs to be updated to include charity withdraw
        // Transfer tokens to the charity.
        UNDERLYING.safeTransfer(CHARITY, underlyingAmount);

        emit DonationWithdraw(underlyingAmount);
    }

    /*///////////////////////////////////////////////////////////////
                        CHARITY ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/




    /*///////////////////////////////////////////////////////////////
                        VAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns a user's Vault balance in underlying tokens.
    /// @return The user's Vault balance in underlying tokens.
    function balanceOfUnderlying(address account) external view returns (uint256) {
        return balanceOf[account].fmul(exchangeRate(), BASE_UNIT);
    }

    /// @notice Returns the amount of underlying tokens an rvToken can be redeemed for.
    /// @return The amount of underlying tokens an rvToken can be redeemed for.
    function exchangeRate() public view returns (uint256) {
        // If there are no rvTokens in circulation, return an exchange rate of 1:1.
        if (totalSupply == 0) return BASE_UNIT;

        // TODO: Optimize double SLOAD of totalSupply here?
        // Calculate the exchange rate by diving the total holdings by the rvToken supply.
        return totalHoldings().fdiv(totalSupply, BASE_UNIT);
    }

    /// @notice Calculate the total amount of tokens the Vault currently holds for depositors.
    /// @return The total amount of tokens the Vault currently holds for depositors.
    function totalHoldings() public view returns (uint256) {
        // Subtract locked profit from the amount of total deposited tokens and add the float value.
        // We subtract locked profit from totalStrategyHoldings because maxLockedProfit is baked into it.
        return totalFloat() + (totalStrategyHoldings - lockedProfit());
    }

    /// @notice Calculate the current amount of locked profit.
    /// @return The current amount of locked profit.
    function lockedProfit() public view returns (uint256) {
        // TODO: Cache SLOADs?
        return
            block.timestamp >= lastHarvest + profitUnlockDelay
                ? 0 // If profit unlock delay has passed, there is no locked profit.
                : maxLockedProfit - (maxLockedProfit * (block.timestamp - lastHarvest)) / profitUnlockDelay;
    }

    /// @notice Returns the amount of underlying tokens that idly sit in the Vault.
    /// @return The amount of underlying tokens that sit idly in the Vault.
    function totalFloat() public view returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                        TRANSPARENT FALLBACK FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Erroneous ether sent will be forward to the charity as a donation
    receive() external payable {
        safeTransfer()
    }

    /// @notice Forwards any unknown calls to the underlying VAULT
    /// @dev Uses the Solidity 0.6 receive split fallback functionality as specified in the blog
    /// @dev https://blog.soliditylang.org/2020/03/26/fallback-receive-split/
    fallback() external payable {
            assembly {
                calldatacopy(0, 0, calldatasize())
                let result := delegatecall(gas(), payable(address(VAULT)), 0, calldatasize(), 0, 0)
                returndatacopy(0, 0, returndatasize())
                switch result
                case 0 { revert(0, returndatasize()) }
                default { return(0, returndatasize()) }
            }
        }
}
