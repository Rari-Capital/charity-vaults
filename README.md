# Charity Vaults

Share interest from Fuse Vaults with charities, friends, and more.

### Getting Started

```sh
git clone https://github.com/Rari-Capital/charity-vaults.git
cd charity-vaults
make
```


### FAQS

1. Are users able to permissionlessly create Vaults?
```
A: Should be yes since the VaultFactory `deployVault` function doesn't have any modifiers or anything.
```

2. How do we envision deposits in a Vault from a ui perspective?
Say I deposit usdc with one referral link for Charity A with a gift rate of 10% of any interest earned.
Then I deposit usdc with a different referral link for Charity B with a gift rate of 20% of any interest earned.
Will the I see a list of the deposits on the UI with each respective interest earned, amount, and gift rate + charity? And I basically have the ability to withdraw x amount from each deposit in one transaction?
```
A:
```

3. Should referrals have the option to choose the underlying asset or does the charity automatically take any donations?
```
A: Yes, Endaoment confirmed they will be able to take any donations.
```

*The below questions refer to how the ui links the charities*
*Like we were thinking, the charities/referrals would be a json list with referral/charity_id to gift_address that can be pr'd into the repo like tokenlists*
*Then all deposits on the ui will pass in the gift address*

*If we want, we can have charities be tracked onchain*

4. Is anybody able to be a charity - like is adding a charity permissionless?
(from the project description it sounds like it can be anyone)
```
A:
```


5. Should referrals have the gift rate optionally set by the charity or it should always be up to the user depositing?
(We _could_ always just not have the ui for the charity to set the rate for a given referral and always allow the user to pass in a gift rate and we verify that the charity didn't already set the rate manually and in that case revert the deposit tx)
```
A:
```

6. *If* the charity is able to set the gift rate, are they able to change the rate for a given referral?
```
A:
```

7. *If* the charity is able to set the gift rate, is anybody able to create a referral link for that charity with a given rate? On the other hand if the charity isn't able to set the gift rate, is a referral link automatically generated for a given charity when a charity is added to the CharityVaults contract?
(from the project description it sounds like it can be anyone)
```
A:
```

8. On withdrawal, it doesn't look like we are able to control where the vault.withdraw function sends the funds?
```
A:
```