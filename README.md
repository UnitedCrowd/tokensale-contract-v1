![UnitedCrowd](https://staging.unitedcrowd.com/github/uc-Logos-gr-l.jpg)
# Tokensale Contract V1.0
The Tokensale contract is an ethereum ERC20 based smart contract designed to initilize and perform an ICO. An ICO is based on classic utility Token.
- Contract requires `SafeMath.sol`, `RefundVault.sol`, `FinalizableCrowdsale.sol`, `UnitedSmartToken.sol`
- Contract based on `solidity ^0.4.18` 


## Feature list
### Token ownership & transfer
Allows the current owner to transfer control of the contract to a newOwner.
newOwner The address to transfer ownership to.

### Vesting incl. the release vested tokens
A token holder contract that can release its token balance gradually like a typical vesting scheme, with a cliff and vesting period. Optionally revocable by the owner.

The vesting schedule is time-based (i.e. using block timestamps as opposed to e.g. block numbers), and is therefore sensitive to timestamp manipulation (which is something miners can do, to a certain degree). Therefore, it is recommended to avoid using short time durations (less than a minute). Typical vesting schemes, with a cliff period of a year and a duration of four years, are safe to use (`solhint-disable`, `not-rely-on-time`).



![Vesting](./docs/vesting.png)
> [view vesting](./docs/vesting.png "View vesting")


### Bounty
Bounty is program which is used for finding the bugs from sc. contract will give the bounty tokens and user have to claim it after certain perioud of time.

### Multsig functions
Which is used when more then one admins in team. While the transaction from contract multisignatures are required.

## Function Overview
#### `UnitedCrowdsale.sol`

Function | Description
--- | ---
onlyWhileSale() | Modifier,  throws if called not during the crowdsale time frame
getRate() | returns the rate in UTC per 1 ETH according to the time of the tx and the UCT pricing program.
finalization() | grants bonuses for the pre crowdsale grantees; enables, re-enables and disables transfers; Enable ETH refunds and token claim; `transferOwnership`
addUpdateGrantee() | Adds/Updates address and token allocation for token grants
deleteGrantee() | deletes entries from the grants list.
setFiatRaisedConvertedToWei() | Set funds collected outside the crowdsale in wei.
claimTokenOwnership(), claimRefundVaultOwnership() | Accepts new ownership on behalf of the UnitedCrowdsale contract. This can be used, by the token sale contract itself to claim back ownership of the UnitedSmartToken contract.
buyTokensWithGuarantee() | Buy tokens with guarantee

#### `UnitedVestingTrustee.sol`
Vesting functions.

Function | Description
--- | ---
grant() | Grant tokens to a specified address; **Vars:** `_to address`: The address to grant tokens to. `_value uint256`: The amount of tokens to be granted. `_start uint256`: The beginning of the vesting period; `_cliff uint256`: Duration of the cliff period; `_end uint256`: determines vesting period; `_revokable bool` Whether the grant is revokable or not;
revoke() | Revoke the grant of tokens of a specifed address.
vestedTokens() | Calculate the total amount of vested tokens of a holder at a given time.
calculateVestedTokens() | Calculate amount of vested tokens at a specifc time.
unlockVestedTokens() | Unlock vested tokens and transfer them to their holder.




