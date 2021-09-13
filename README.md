# Charity Vaults

Share interest from Fuse Vaults with charities, friends, and more.

### Getting Started

```sh
git clone https://github.com/Rari-Capital/charity-vaults.git
cd charity-vaults
make
```


### Questions

Are users able to permissionlessly create Vaults?

How do we envision deposits in a Vault from a ui perspective?
Say I deposit usdc with one referral link for Charity A with a gift rate of 10% of any interest earned.
Then I deposit usdc with a different referral link for Charity B with a gift rate of 20% of any interest earned.
Will the I see a list of the deposits on the UI with each respective interest earned, amount, and gift rate + charity? And I basically have the ability to withdraw x amount from each deposit in one transaction?

Should referrals have the option to choose the underlying asset or does the charity automatically take any donations?

Should referrals have the gift rate optionally set by the charity or it should always be up to the user depositing?
(We _could_ always just not have the ui for the charity to set the rate for a given referral and always allow the user to pass in a gift rate and we verify that the charity didn't already set the rate manually and in that case revert the deposit tx)

Is anybody able to be a charity - like is adding a charity permissionless?

