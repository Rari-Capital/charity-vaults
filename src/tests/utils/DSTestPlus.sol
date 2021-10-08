// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {DSTestPlus as DSTest} from "solmate/test/utils/DSTestPlus.sol";
import {ERC20} from "solmate/erc20/ERC20.sol";

import {Vault} from "vaults/Vault.sol";
import {CharityVault} from "../../CharityVault.sol";

contract DSTestPlus is DSTest {
    function assertERC20Eq(ERC20 erc1, ERC20 erc2) internal {
        assertEq(address(erc1), address(erc2));
    }

    function assertVaultEq(Vault va, Vault vb) public {
        assertEq(address(va), address(vb));
    }

    function assertCharityVaultEq(CharityVault cva, CharityVault cvb) public {
        assertEq(address(cva), address(cvb));
    }
}
