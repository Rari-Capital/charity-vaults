// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {ERC20} from "solmate/erc20/ERC20.sol";
import {SafeERC20} from "solmate/erc20/SafeERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Strategy} from "vaults/Strategy.sol";

/// @title CharityVaultStrategy
/// @notice This is essentially a malicious strategy that over-reports a user's balance
contract CharityVaultStrategy is
    Strategy,
    ERC20("CV Mock Strategy", "cvsMOCK", 18)
{
    using SafeERC20 for ERC20;
    using FixedPointMathLib for uint256;

    ERC20 public immutable override underlying;

    uint256 public immutable BASE_UNIT;

    function mint() external payable {}

    function isCEther() external pure returns (bool) {
        return false;
    }

    constructor(ERC20 _underlying) {
        underlying = _underlying;

        BASE_UNIT = 10**_underlying.decimals();
    }

    function mint(uint256 underlyingAmount)
        external
        override
        returns (uint256)
    {
        // Convert underlying tokens to cTokens and mint them.
        _mint(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        // Transfer in underlying tokens from the sender.
        underlying.safeTransferFrom(
            msg.sender,
            address(this),
            underlyingAmount
        );

        return 0;
    }

    function redeemUnderlying(uint256 underlyingAmount)
        external
        override
        returns (uint256)
    {
        // Convert underlying tokens to cTokens and then burn them.
        _burn(msg.sender, underlyingAmount.fdiv(exchangeRate(), BASE_UNIT));

        // Calculate a 10% accrual
        uint256 ten_percent = underlyingAmount.fdiv(
            underlyingAmount.fmul(10, BASE_UNIT),
            BASE_UNIT
        );

        // Transfer underlying tokens to the caller.
        underlying.safeTransfer(msg.sender, underlyingAmount + ten_percent);

        return 0;
    }

    function simulateLoss(uint256 underlyingAmount) external {
        underlying.safeTransfer(
            0x000000000000000000000000000000000000dEaD,
            underlyingAmount
        );
    }

    function balanceOfUnderlying(address account)
        external
        view
        override
        returns (uint256)
    {
        return balanceOf[account].fmul(exchangeRate(), BASE_UNIT);
    }

    function exchangeRate() internal view returns (uint256) {
        // If there are no cTokens in circulation, return an exchange rate of 1:1.
        if (totalSupply == 0) return BASE_UNIT;

        // TODO: Optimize double SLOAD of totalSupply here?
        return underlying.balanceOf(address(this)).fdiv(totalSupply, BASE_UNIT);
    }
}
