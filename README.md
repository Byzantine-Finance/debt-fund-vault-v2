# Debt Fund Vault V2

**Debt Fund Vault V2** is a fork of [Morpho Vault v2](https://github.com/morpho-org/vault-v2) that extends the original protocol with two new adapters:

- **Compound V3 Adapter** - Direct integration with Compound Comet V3
- **ERC4626 Merkl Adapter** - Support for any ERC4626-compliant protocol with Merkl eligible rewards

This enables more flexible asset allocation strategies while maintaining the core benefits of Morpho Vault v2: depositors earn from underlying protocols without actively managing risk positions, while robust role-based systems handle asset allocation and risk management.

Debt Fund Vault V2 enables anyone to create [non-custodial](#non-custodial-guarantees) vaults that allocate assets to any protocols, including but not limited to Morpho Market v1, Morpho Market v2, Morpho Vault v1, Compound V3 and any other ERC4626-compatible protocols.
Depositors of Morpho Vault v2 earn from the underlying protocols without having to actively manage the risk of their position.
Management of deposited assets is the responsibility of a set of different roles (owner, curator and allocators).
The active management of invested positions involves enabling and allocating liquidity to protocols.

[Debt Fund Vault V2](./src/VaultV2.sol) is [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) and [ERC-2612](https://eips.ethereum.org/EIPS/eip-2612) compliant.
The [VaultV2Factory](./src/VaultV2Factory.sol) deploys instances of Debt Fund Vault V2.
All the contracts are immutable.

## Overview

### Adapters

Vaults can allocate assets to arbitrary protocols and markets via adapters, or use an adapter registry to add restrictions to allowed adapters.
The curator enables adapters to hold positions on behalf of the vault.
Adapters are also used to know how much these investments are worth (interest and loss realization).
Because adapters hold positions in protocols where assets are allocated, they are susceptible to accrue [Rewards](#Rewards) for those protocols.

Adapters for the following protocols are currently available:

- [Morpho Market v1](./src/adapters/MorphoMarketV1Adapter.sol).
  This adapter allocates to any Morpho Market v1, constrained by the allocation caps (see [Id system](#id-system) below).
  The adapter holds a position on each respective market, on behalf of the debt fund vault v2.
- [Morpho Vault v1](./src/adapters/MorphoVaultV1Adapter.sol).
  This adapter allocates to a fixed Morpho Vault v1 (v1.0 and v1.1).
  The adapter holds shares of the corresponding Morpho Vault v1 (v1.0 and v1.1) on behalf of the debt fund vault v2.
- [Compound v3](src/adapters/CompoundV3Adapter.sol).
  This adapter allocates to a fixed Compound v3 vault.
  The adapter holds shares of the corresponding Compound v3 vault on behalf of the debt fund vault v2.
- [ERC4626 Merkl](src/adapters/ERC4626MerklAdapter.sol).
  This adapter allocates to any fixed underlying protocol that is ERC4624 compliant, such as Stata, Sky protocol, Euler and many ohters. This adapter can also used to allocate assets to AAVE via a Stata vault which is AAVE ERC4626 wrapper.
  The adapter holds shares of the corresponding protocol on behalf of the debt fund vault v2.

### Id system

The funds allocation of the vault is constrained by an id system.
An id is an abstract identifier for a common risk factor of some markets (a collateral, an oracle, a protocol, etc.).
Allocation on markets with a common id is limited by absolute caps and relative caps.
Note that relative caps are "soft" because they are not checked on withdrawals, they only constrain new allocations.
The curator ensures the consistency of the id system by:

- setting caps for the ids according to an estimation of risk;
- setting adapters that return consistent ids.

The ids of Morpho v1 lending markets could be for example the market parameters `(LoanToken, CollateralToken, Oracle, IRM, LLTV)` and `CollateralToken` alone.
A vault could be set up to enforce the following caps:

- `(loanToken, stEth, chainlink, irm, 86%)`: 10M
- `(loanToken, stETH, redstone, irm, 86%)`: 10M
- `stETH`: 15M

This would ensure that the vault never has more than 15M exposure to markets with stETH as collateral, and never more than 10M exposure to an individual market.

### Liquidity

The allocator is responsible for ensuring that users can withdraw their assets at any time.
This is done by managing the available idle liquidity and an optional liquidity adapter.

When users withdraw assets, the idle assets are taken in priority.
If there is not enough idle liquidity, liquidity is taken from the liquidity adapter.
When defined, the liquidity adapter is also used to forward deposited funds.

A typical liquidity adapter would allow deposits/withdrawals to go through a very liquid Market v1.

### Non-custodial guarantees

Non-custodial guarantees come from [in-kind redemptions](#in-kind-redemptions-with-forcedeallocate) and [timelocks](#curator-timelocks).
These mechanisms allow users to withdraw their assets before any critical configuration change takes effect.

### In-kind redemptions with `forceDeallocate`

To guarantee exits even in the absence of assets immediately available for withdrawal, the permissionless `forceDeallocate` function allows anyone to move assets from an adapter to the vault's idle assets.

Users can redeem in-kind thanks to the `forceDeallocate` function: flashloan liquidity, supply it to an adapter's market, and withdraw the liquidity through `forceDeallocate` before repaying the flashloan.
This reduces their position in the vault and increases their position in the underlying market.

A penalty for using forceDeallocate can be set per adapter, of up to 2%.
This disincentivizes the manipulation of allocations, in particular of relative caps which are not checked on withdrawals.
Note that the only friction to deallocating an adapter with a 0% penalty is the associated gas cost.

### Gates

Vaults v2 can use external gate contracts to control share transfer, vault asset deposit, and vault asset withdrawal.

If a gate is not set, its corresponding operations are not restricted.

Gate changes can be timelocked.
By setting the timelock to `type(uint256).max`, a curator can commit to an irreversible gate setup.

Four gates are defined:

**Receive shares gate** (`receiveSharesGate`): Controls the permission to receive shares.

Upon `deposit`/`mint`, `transfer`/`transferFrom`, and interest accrual (for both fee recipients), `canReceiveShares` must return `true` for the shares recipient if the gate is set.

This gate is critical because it can prevent depositors from getting back their shares deposited on other contracts. Also, if it reverts and there is a non-zero fee, interest accrual reverts.

**Send shares gate** (`sendShareGate`): Controls the permission to send shares.

Upon `withdraw`/`redeem` and `transfer`/`transferFrom`, `canSendShares` must return `true` for the shares sender if the gate is set.

This gate is critical because it can prevent people from withdrawing their shares, or prevent depositors from getting back their shares deposited on other contract.

**Receive Assets Gate** (`receiveAssetsGate`): Controls permissions related to receiving assets.

Upon `withdraw`/`redeem`, `canReceiveAssets` must return true for the `receiver` if the gate is set.

This gate is critical because it can prevent people from receiving their assets upon withdrawals.

**Send Assets Gate** (`sendAssetsGate`): Controls permissions related to sending assets.

Upon `deposit`/`mint`, `canSendAssets` must return true for `msg.sender` must pass the `canSendAssets` check.

### Roles

#### Owner

The owner's role is to set the curator and sentinels.
Only one address can have this role.

It can:

- Set the owner.
- Set the curator.
- Set sentinels.
- Set the name.
- Set the symbol.

#### Curator

The curator's role is to curate the vault, meaning setting risk limits, gates, allocators, fees.
Only one address can have this role.

Curator actions are timelockable, except decreaseAbsoluteCap and decreaseRelativeCap.
Once the timelock has passed, the action can be executed by anyone.

It can:

<a id="curator-timelocks"></a>

- [Timelockable] Increase absolute caps.
- Decrease absolute caps.
- [Timelockable] Increase relative caps.
- Decrease relative caps.
- [Timelockable] Set the adapter registry.
- [Timelockable] Set adapters.
- [Timelockable] Set allocators.
- [Timelockable] Increase timelocks.
- [Timelocked by the timelock being decreased] Decrease timelocks.
- [Timelockable] Set the `performanceFee`.
  The performance fee is capped at 50% of generated interest.
- [Timelockable] Set the `managementFee`.
  The management fee is capped at 5% of assets under management annually.
- [Timelockable] Set the `performanceFeeRecipient`.
- [Timelockable] Set the `managementFeeRecipient`.
  increaseTimelock should be used carefully, because decreaseTimelock is timelocked with the timelock itself. In particular it is possible to make an action irreversible (which is a feature in itself). A timelock of `type(uint256).max` is a recommended convention for making an action irreversible.

#### Allocator

The allocators' role is to handle the allocation of the liquidity (inside the caps set by the curator).
They are notably responsible for the vault's liquidity.
Multiple addresses can have this role.

It can:

- Allocate funds from the “idle market” to enabled markets.
- Deallocate funds from enabled markets to the “idle market”.
- Set the `liquidityAdapter` and the `liquidityData`.
- Set the `maxRate`.

#### Sentinel

Multiple addresses can have this role.

It can:

- Deallocate funds from enabled markets to the “idle market”.
- Decrease absolute caps.
- Decrease relative caps.
- Revoke timelocked actions.

### Rewards management

In Debt Fund Vault V2, all eligible adapters automatically claim and process rewards for the vault's benefit.

#### Claiming rewards

To ensure that those rewards can be retrieved, the Compound V3 and ERC4626 Merkl adapters have a claim function that can be called by the autorized claimer. All claimed rewards are instantly swapped to USDC, and transfer them to the vault for consistent value accrual.

While both adapters share the same claim function interface, their underlying reward claiming mechanisms differ:

- Compound V3 Adapter uses onchain rewards distribution as rewards are accrued every second (see [CometRewards](https://etherscan.io/address/0x1B0e765F6224C21223AeA2af16c1C46E38885a40#code) logic)
- ERC4626 Merkl Adapter allows claiming rewards via [Merkl Distributor](https://etherscan.io/address/0x0e6590f64a82cbc838b2a087281689de1a5bc8e0#code) using merkle proofs

#### Swap to USDC

Debt Fund Vault V2 recommends to use [LI.FI](https://li.fi/) to automatically swap all claimed rewards to USDC and send it to the vault, routing through the DEX that offers the best quote at execution time.

To streamline the generation and encoding of the claim data, giving the Merkle proofs and the best swapping route, Byzantine has developped a [dedicated program](https://github.com/Byzantine-Finance/rewards-claimer). Reach out to get access to the repo.

For the eligible vaults, the claimer is an automated program that runs daily and performs the following tasks:

1. **Scan all vault adapters** - Check available rewards for claiming across all connected adapters
2. **Generate optimal quotes** - Request LI.FI quotes and prepare claim data for execution
3. **Execute claims** - Call the claim function on each adapter to swap rewards to USDC and transfer them to the vault

## Getting started

### Package installation

Install [Foundry](https://book.getfoundry.sh/getting-started/installation).

### Run tests

Run `forge test`.

## License

Files in this repository are publicly available under license `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).
