// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {Auth} from "solmate/auth/Auth.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";

import {WETH} from "./external/WETH.sol";
import {CErc20} from "./external/CErc20.sol";

import "./tests/utils/DSTestPlus.sol";

/// @title Fuse Charity Vault (fcvToken)
/// @author Transmissions11, JetJadeja, [Andreas Bigger, Nicolas Neven](some random usc kids)
/// @notice Yield bearing token that enables users to swap
/// their underlying asset to instantly begin earning yield.
contract CharityVault is Vault {
    using SafeERC20 for ERC20;

    /*///////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address payable public immutable charity;
    uint256 public immutable feePercent;

    /// @notice Creates a new charity vault based on an underlying token.
    /// @param _underlying An underlying ERC20 compliant token.
    /// @param _charity The address of the charity
    /// @param _feePercent The percent of earned interest to be routed to the Charity
    constructor(ERC20 _underlying, address payable _charity, uint256 _feePercent)
        // ERC20(
        //     // ex: Fuse DAI Charity Vault
        //     string(abi.encodePacked("Fuse ", _underlying.name(), " Charity Vault")),
        //     // ex: fcvDAI
        //     string(abi.encodePacked("fcv", _underlying.symbol())),
        //     // ex: 18
        //     _underlying.decimals()
        // )
    {
        // Enforce feePercent
        require(_feePercent >= 0 && _feePercent <= 100, "Fee Percent fails to meet [0, 100] bounds constraint.");

        underlying = _underlying;
        charity = _charity;
        feePercent = _feePercent;
    }

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

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

    receive() external payable {}
}
