pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./CharityVaults.sol";

contract CharityVaultsTest is DSTest {
    CharityVaults vaults;

    function setUp() public {
        vaults = new CharityVaults();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
