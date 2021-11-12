// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ERC20Strategy} from "vaults/interfaces/Strategy.sol";

/// @title CharityVaultMockStrategy
/// @notice This is essentially a malicious strategy that over-reports a user's balance
contract CharityVaultMockStrategy is
    ERC20("CV Mock Strategy", "cvsMOCK", 18),
    ERC20Strategy
{
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                           STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(ERC20 _underlying) {
        UNDERLYING = _underlying;

        BASE_UNIT = 10**_underlying.decimals();
    }

    function isCEther() external pure override returns (bool) {
        return false;
    }

    function underlying() external view override returns (ERC20) {
        return UNDERLYING;
    }

    function mint(uint256 amount) external override returns (uint256) {
        _mint(msg.sender, amount.fdiv(exchangeRate(), BASE_UNIT));

        UNDERLYING.safeTransferFrom(msg.sender, address(this), amount);

        return 0;
    }

    function redeemUnderlying(uint256 amount)
        external
        override
        returns (uint256)
    {
        _burn(msg.sender, amount.fdiv(exchangeRate(), BASE_UNIT));

        // !! ----------------------------------------- !! //
        // !! Mock Interest by Manipulating totalSupply !! //
        // !! ----------------------------------------- !! //
        // UNDERLYING.mint(address(this), 0.5e18);
        // !! ----------------------------------------- !! //

        UNDERLYING.safeTransfer(msg.sender, amount);

        return 0;
    }

    function balanceOfUnderlying(address user)
        external
        view
        override
        returns (uint256)
    {
        return balanceOf[user].fmul(exchangeRate(), BASE_UNIT);
    }

    /*///////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    // solhint-disable-next-line var-name-mixedcase
    ERC20 internal immutable UNDERLYING;

    // solhint-disable-next-line var-name-mixedcase
    uint256 internal immutable BASE_UNIT;

    function exchangeRate() internal view returns (uint256) {
        uint256 cTokenSupply = totalSupply;

        if (cTokenSupply == 0) return BASE_UNIT;

        return
            UNDERLYING.balanceOf(address(this)).fdiv(cTokenSupply, BASE_UNIT);
    }

    /*///////////////////////////////////////////////////////////////
                             MOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function simulateLoss(uint256 underlyingAmount) external {
        UNDERLYING.safeTransfer(address(0xDEAD), underlyingAmount);
    }
}
