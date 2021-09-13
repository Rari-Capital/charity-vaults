// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.6;

import "vaults/VaultFactory.sol";

// import {Bytes32AddressLib} from "./libraries/Bytes32AddressLib.sol";

/// @title Fuse Charity Vault Factory
/// @author Transmissions11, JetJadeja, some_random_usc_kids
/// @notice Charity wrapper for vaults/VaultFactory.
contract CharityVaults {
    /// @dev This factory is already deployed
    VaultFactory public factory;

    /// @notice Creates a CharityVault
    constructor(address _deployed_vault_factory) {
        charities = new Charity[]();
        factory = new VaultFactory(_deployed_vault_factory);
    }

    /// TODO: Internal store to track user-specified rates
    /// TODO: Map referals to their Charity of choice

    /// @notice users can send percents to any address (ex endaoment address)

    /// TODO: interest is sent on withdraw
    /// TODO: only the carity vault donation recipient can call the withdraw function to withdraw their interest

    /// @notice Referral
    struct Referral {
        uint256 id;
        uint256 charity_id;
        // TODO: is this optional - should the charity be able to set the gift_percent at all?
        bool is_gift_percent_set;
        uint256 gift_percent;
    }

    /// @notice mapping from referral id to a Referral Object
    mapping(uint256 => Referral) public referrals;

    /// @notice Charity
    struct Charity {
        uint256 charity_id;
        string name;
        address donation_address;
        address[] approved_referral_creators;
        /// TODO: add assets in the Charity Vault - then we swap through uniswap v3
    }

    modifier approvedCharityCreators(Charity charity) {
        require(charity.approved_referral_creators.contains(msg.sender), "msg.sender is not approved for this charity!");
        _;
    }

    // TODO: add Referral Function
    // TODO: Delete Referral Function
    // TODO: *If* the charity is able to set the gift rate, are they able to change the rate for a given referral?
        // TODO: then, we would need edit referral logic

    /// @notice A list of approved charities
    Charity[] private charities;

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted after a Charity is added to the list of approved charities
    /// @param charity The new Charity Object added
    event CharityAdded(Charity charity);

    /// @notice Emitted after a Charity is removed from the list of approved charities
    /// @param charity The Charity Object removed
    event CharityRemoved(Charity charity);

    /// @notice Emitted after a Charity is removed from the list of approved charities
    /// @param charity The Charity Object removed
    event CharityEdited(Charity charity);

    /// @notice Allows a given owner to add to the list of approved charities
    /// @param charity The new Charity Object to be added
    function addCharity(Charity charity) external onlyOwner {
        charities.push(charity);
        emit CharityAdded(charity);
    }

    /// @notice Allows a given owner to remove a charity from the list of approved charities
    /// @param index The index of the charity object to be removed
    function removeCharity(uint256 index) external onlyOwner {
        Charity charity = charities[index];
        charities[index] = charities[charities.length - 1];
        charities.pop();
        emit CharityRemoved(charity);
    }


    // TODO: Edit Charity Function - for changing name and donation_address


    /// @notice Deposit the vault's underlying token to mint fvTokens.
    /// @param underlyingAmount The amount of the underlying token to deposit.
    /// @param underlying The underlying ERC20 token the Vault earns yield on.
    function deposit(
        uint256 underlyingAmount,
        ERC20 underlying,
        uint256 referral_id
    ) external {
        // Get the respective Vault
        Vault vault = factory.getVaultFromUnderlying(underlying);

        // TODO: this function should take a list of deposits for various vaults/underlying assets,

        // Fetch the Referral Object from the provided referral_id
        Referral referral = referrals[referral_id];

        max_deposit_id += 1;
        uint256 deposit_id = max_deposit_id;
        deposits[deposit_id] = new Deposit(
            deposit_id,
            vault,
            underlyingAmount,
            referral
        );
        user_deposits.push(deposit_id);

        // Relay deposit to the respective vault
        vault.deposit(underlyingAmount);
    }

    /// @notice Burns fvTokens and sends underlying tokens to the caller.
    /// @param amount The amount of fvTokens to redeem for underlying tokens.
    function withdraw(
        uint256 amount,
        ERC20 underlying,
        uint256 deposit_id
    ) external {
        // Get the respective Vault
        Vault vault = factory.getVaultFromUnderlying(underlying);

        // TODO: this function should take a list of withdraws for various vaults/underlying assets,

        // Fetch the Deposit Object from the provided deposit_id
        Deposit deposit = deposits[deposit_id];

        // TODO: determine charity rate withdraw mechanics

        // Relay withdraw to the respective vault
        vault.withdraw(amount);
    }

    /// @notice Fetches the user's balance for the Vault with the provided underlying asset
    /// @param user A given EOA.
    /// @param underlying The underlying ERC20 token the Vault earns yield on.
    /// @return uint256 The balance of the user for the specified vault
    function getVaultBalance(address user, ERC20 underlying)
        external
        view
        returns (uint256)
    {
        // Get the respective Vault
        Vault vault = factory.getVaultFromUnderlying(underlying);

        // Return the balanceOf user
        return vault.balanceOf(user);
    }
}
