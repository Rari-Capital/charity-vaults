// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {Auth} from "solmate/auth/Auth.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";

/// @title Fuse Charity Vault (fcvToken)
/// @author Transmissions11, JetJadeja, Andreas Bigger, Nicolas Neven, Adam Egyed
/// @notice Yield bearing token that enables users to swap
/// their underlying asset to instantly begin earning yield
/// where a percent of the earned interest is sent to charity.
contract CharityVault is ERC20, Auth {
    using SafeERC20 for ERC20;
    
    /*///////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev we need to compose a Vault here because the Vault functions are external
    /// @dev which are not able to be overridden since that requires public virtual specifiers
    Vault private vault;

    /// @notice The underlying token for the vault.
    ERC20 public immutable underlying;

    /// @notice the charity's payable donation address
    address payable public immutable charity;

    /// @notice the percent of the earned interest that should be redirected to the charity
    uint256 public immutable feePercent;

    /// @notice Creates a new charity vault based on an underlying token.
    /// @param _underlying An underlying ERC20 compliant token.
    /// @param _charity The address of the charity
    /// @param _feePercent The percent of earned interest to be routed to the Charity
    constructor(ERC20 _underlying, address payable _charity, uint256 _feePercent)
        ERC20(
            // ex: Fuse DAI Charity Vault
            string(abi.encodePacked("Fuse ", _underlying.name(), " Charity Vault")),
            // ex: fcvDAI
            string(abi.encodePacked("fcv", _underlying.symbol())),
            // ex: 18
            _underlying.decimals()
        )
    {
        // Enforce feePercent
        require(_feePercent >= 0 && _feePercent <= 100, "Fee Percent fails to meet [0, 100] bounds constraint.");

        // Define our constants
        underlying = _underlying;
        charity = _charity;
        feePercent = _feePercent;
        vault = new Vault(_underlying);
    }

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after a successful deposit.
    /// @param user The address of the account that deposited into the vault.
    /// @param underlyingAmount The amount of underlying tokens that were deposited.
    event CharityDeposit(address user, uint256 underlyingAmount);

    /// @notice Emitted after a successful withdrawal.
    /// @param user The address of the account that withdrew from the vault.
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event CharityWithdraw(address user, uint256 underlyingAmount);

    /// @notice Emitted when a Charity successfully withdraws their fee percent of earned interest.
    /// @notice Address withdrawan to is not needed because there is only one charity address for a given CharityVault
    /// @param underlyingAmount The amount of underlying tokens that were withdrawn.
    event CharityWithdraw(uint256 underlyingAmount);

    /*///////////////////////////////////////////////////////////////
                         USER ACTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit the vault's underlying token to mint fcvTokens.
    /// @param underlyingAmount The amount of the underlying token to deposit.
    function deposit(uint256 underlyingAmount) external virtual override {
        _mint(msg.sender, (underlyingAmount * 10**decimals) / exchangeRateCurrent());

        // Transfer in underlying tokens from the sender.
        underlying.safeTransferFrom(msg.sender, address(this), underlyingAmount);

        emit Deposit(msg.sender, underlyingAmount);
    }

    /// @notice Burns fcvTokens and sends underlying tokens to the caller.
    /// @param amount The amount of fcvTokens to redeem for underlying tokens.
    function withdraw(uint256 amount) external override {
        // Query the vault's exchange rate.
        uint256 exchangeRate = exchangeRateCurrent();

        // Convert the amount of fcvTokens to underlying tokens.
        // This can be done by multiplying the fcvTokens by the exchange rate.
        uint256 underlyingAmount = (exchangeRate * amount) / 10**decimals;

        // Burn inputed fcvTokens.
        _burn(msg.sender, amount);

        // If the withdrawal amount is greater than the float, pull tokens from Fuse.
        if (underlyingAmount > getFloat()) pullIntoFloat(underlyingAmount);

        // TODO: this needs to be updated to include charity withdraw
        // Transfer tokens to the caller.
        underlying.safeTransfer(msg.sender, underlyingAmount);

        emit Withdraw(msg.sender, underlyingAmount);
    }

    /// @notice Burns fcvTokens and sends underlying tokens to the caller.
    /// @param underlyingAmount The amount of underlying tokens to withdraw.
    function withdrawUnderlying(uint256 underlyingAmount) external override {
        // Query the vault's exchange rate.
        uint256 exchangeRate = exchangeRateCurrent();

        // Convert underlying tokens to fcvTokens and then burn them.
        // This can be done by multiplying the underlying tokens by the exchange rate.
        _burn(msg.sender, (exchangeRate * underlyingAmount) / 10**decimals);

        // If the withdrawal amount is greater than the float, pull tokens from Fuse.
        if (getFloat() < underlyingAmount) pullIntoFloat(underlyingAmount);

        // TODO: this needs to be updated to calculate how much use should get
        // Transfer underlying tokens to the sender.
        underlying.safeTransfer(msg.sender, underlyingAmount);

        emit Withdraw(msg.sender, underlyingAmount);
    }

    // TODO: Charity Withdraw function
    // TODO: this function should only be callable by the charity

    /*///////////////////////////////////////////////////////////////
                         SHARE PRICE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns a user's balance in underlying tokens.
    /// @dev Fetch the underlying balance for the user from the composed Vault
    function balanceOfUnderlying(address account) external view returns (uint256) {
        return vault.balanceOfUnderlying(account);
    }

    /// @notice Returns the current fcvToken exchange rate, scaled by 1e18.
    function exchangeRateCurrent() public view returns (uint256) {
        // Store the vault's total underlying balance and fcvToken supply.
        uint256 supply = totalSupply;
        uint256 balance = calculateTotalFreeUnderlying();

        // If the supply or balance is zero, return an exchange rate of 1.
        if (supply == 0 || balance == 0) return 10**decimals;

        // Calculate the exchange rate by diving the underlying balance by the fcvToken supply.
        return (balance * 10**decimals) / supply;
    }

    /*///////////////////////////////////////////////////////////////
                           CALCULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the amount of underlying tokens that idly sit in the vault.
    /// @dev The Float is handled inside the Vault
    function getFloat() public view returns (uint256) {
        return vault.getFloat();
    }

    /// @notice Calculate the total amount of free underlying tokens.
    function calculateTotalFreeUnderlying() public view returns (uint256) {
        // Subtract locked profit from the amount of total deposited tokens and add the float value.
        // We subtract the locked profit from the total deposited tokens because it is included in totalDeposited.
        return getFloat() + vault.totalDeposited() - vault.calculateLockedProfit();
    }

    /// @notice Calculate the total amount of free underlying tokens.
    function calculateDepositorTotalFreeUnderlying() public view returns (uint256) {
        // Subtract locked profit from the amount of total deposited tokens and add the float value.
        // We subtract the locked profit from the total deposited tokens because it is included in totalDeposited.
        // Multiply by 1 - the percent to be donated to charity
        return (getFloat() + vault.totalDeposited() - vault.calculateLockedProfit()) * ((100.0 - feePercent) / 100.0);
    }

    /// @notice Calculate the total amount of free underlying tokens.
    function calculateCharityTotalFreeUnderlying() public view returns (uint256) {
        // Subtract locked profit from the amount of total deposited tokens and add the float value.
        // We subtract the locked profit from the total deposited tokens because it is included in totalDeposited.
        // Multiply by the percent to be donated to charity
        return (getFloat() + vault.totalDeposited() - vault.calculateLockedProfit()) * (feePercent / 100.0);
    }



    receive() external payable {}
}
