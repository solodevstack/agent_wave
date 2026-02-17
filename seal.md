# AgentWave — Walrus Seal Integration

This document describes the complete Seal (encrypted blob access control) implementation in the AgentWave smart contract package. It is written for AI agents that need to call, reason about, or extend this system.

---

## Overview

A **deliverable blob** (e.g. a report, dataset, or work artifact) is uploaded by the **main agent** to Walrus and encrypted using Sui Seal. The blob stays sealed — unreadable by anyone — until the **auditor** reviews the work and marks the escrow as audited on-chain. Once audited, **only the client** can decrypt and access the blob.

```
Main Agent uploads blob → encrypts with Seal key → blob stored on Walrus (sealed)
                                                              ↓
                                              Auditor calls mark_as_audited()
                                                              ↓
                                              is_audited = true on AgenticEscrow
                                                              ↓
                                              Client calls seal_approve → decrypts blob
```

---

## Roles

| Role | Address source | Responsibility |
|---|---|---|
| **Client** | `AgenticEscrow.client` | Pays for the job; is the sole decryptor of the blob |
| **Main Agent** | `AgenticEscrow.main_agent` | Does the work; uploads the blob; creates the Allowlist |
| **Auditor** | `AgenticEscrow.auditor` | Reviews work; calls `mark_as_audited` to unlock the blob |
| **Custodian** | `@custodian_addr` (compile-time constant) | Resolves disputes; has no special role in Seal |

---

## Modules

The package (`agentwave_contract`) contains three modules relevant to Seal:

| Module | File | Purpose |
|---|---|---|
| `agentwave_contract` | `sources/agentwave_contract.move` | Core escrow logic + auditor fields + helper getters |
| `walrus_seal` | `sources/walrus_seal.move` | Full Allowlist-based Seal integration |
| `seal_policies` | `sources/seal_policies.move` | Lightweight stateless policy (no Allowlist object needed) |

---

## Escrow Fields Added for Seal

The following fields were added to the `AgenticEscrow` struct:

```move
auditor: address,       // Agent designated to audit the deliverable
is_audited: bool,       // false at creation; set to true by auditor
allowlist_id: Option<ID>, // ID of the walrus_seal::Allowlist object, if created
```

These fields are also exposed on `AgenticEscrowInfo` (the read-only view struct):

```move
auditor: address,
is_audited: bool,
```

### Getter functions (on AgenticEscrowTable)

```move
public fun get_auditor(escrow_table: &AgenticEscrowTable, escrow_id: ID): address
public fun get_is_audited(escrow_table: &AgenticEscrowTable, escrow_id: ID): bool
public fun check_allowlist_is_some(escrow_id: ID, escrow_table: &AgenticEscrowTable): bool
```

---

## Module: `agentwave_contract`

### Escrow creation — auditor parameter

`create_agentic_escrow` now requires an `auditor: address` argument:

```move
public fun create_agentic_escrow(
    escrow_table: &mut AgenticEscrowTable,
    main_agent: address,
    auditor: address,           // NEW — the auditor agent address
    job_title: String,
    job_description: String,
    job_category: String,
    duration: u8,
    budget: u64,
    main_agent_price: u64,
    payment_coin: Coin<SUI>,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
)
```

The escrow is created with `is_audited: false` and `allowlist_id: option::none()`.

---

### `mark_as_audited`

**Who calls it:** The auditor (`escrow.auditor`).
**When:** After reviewing the deliverable and confirming it is satisfactory.
**Effect:** Sets `is_audited = true`, which unlocks the sealed blob for the client.

```move
public fun mark_as_audited(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
)
```

**Guards:**
- Aborts `ENotAuthorized (1)` if `ctx.sender() != escrow.auditor`
- Aborts `EAlreadyAudited (12)` if already audited

**Emits:** `EscrowAudited { escrow_id, auditor, timestamp }`

---

### `add_allowlist_id` (called internally by `walrus_seal`)

Stores the Allowlist object ID on the escrow. An AI agent does **not** call this directly — it is called inside `walrus_seal::create_allowlist`.

```move
public fun add_allowlist_id(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    allowlist_id: ID,
    _ctx: &mut TxContext
)
```

---

## Module: `walrus_seal`

Full-featured Seal integration backed by an on-chain `Allowlist` shared object.

### Structs

```move
public struct Allowlist has key {
    id: UID,
    name: String,
    client: address,   // client recorded at creation; for off-chain reference only
}

public struct Cap has key {
    id: UID,
    allowlist_id: ID,  // must match the Allowlist this Cap manages
}
```

The `Allowlist` object's **object ID** is used as the encryption namespace. The `Cap` is transferred to the caller (main agent) and is required to publish blobs.

---

### Step 1 — Create the Allowlist

**Who calls it:** Main agent (after uploading the blob to Walrus).
**Call:** `create_allowlist_entry` (the entry wrapper, which transfers the Cap to `ctx.sender()`).

```move
entry fun create_allowlist_entry(
    name: String,
    escrow_table: &mut AgenticEscrowTable,
    escrow_id: ID,
    ctx: &mut TxContext
)
```

Internally:
- Creates a shared `Allowlist` object with `client` field set from the escrow
- Creates a `Cap` object and transfers it to the caller
- Stores the `Allowlist` object ID on the escrow via `add_allowlist_id`
- Aborts `EAllowlistExists (3)` if an allowlist was already created for this escrow

---

### Step 2 — Publish the blob

**Who calls it:** Main agent (holder of the `Cap`).

```move
public fun publish(
    allowlist: &mut Allowlist,
    cap: &Cap,
    _escrow_table: &AgenticEscrowTable,
    blob_id: String,
)
```

- Attaches the Walrus `blob_id` string as a dynamic field on the Allowlist object
- Aborts `EInvalidCap (0)` if `cap.allowlist_id != object::id(allowlist)`
- The blob remains sealed until `is_audited == true`

---

### Step 3 — Auditor unlocks

**Who calls it:** Auditor.

```move
public fun mark_as_audited(   // in agentwave_contract module
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
)
```

This is the **only action that changes `is_audited`**. No other party can trigger this.

---

### Step 4 — Client decrypts (seal_approve)

**Who calls it:** Sui Seal service (on behalf of the client trying to decrypt).

```move
entry fun seal_approve(
    id: vector<u8>,
    escrow_table: &AgenticEscrowTable,
    escrow_id: ID,
    allowlist: &Allowlist,
    ctx: &TxContext,
)
```

**Three conditions must ALL be true or it aborts `ENoAccess (1)`:**

| # | Check | Detail |
|---|---|---|
| 1 | **Namespace prefix** | `id` must start with `allowlist.id.to_bytes()` |
| 2 | **Audit gate** | `get_is_audited(escrow_table, escrow_id) == true` |
| 3 | **Client only** | `ctx.sender() == get_client(escrow_table, escrow_id)` |

**Security note:** Check 3 reads the client address live from the escrow state, not from any mutable field on the Allowlist. There is no `add()` function — no one can expand access after creation.

---

### Encryption Key ID Format (walrus_seal)

When the main agent encrypts the blob, the Seal key identity must be:

```
key_id = allowlist_object_id_bytes ++ random_nonce
```

- `allowlist_object_id_bytes` = 32-byte object ID of the `Allowlist` shared object
- `random_nonce` = any additional bytes (at minimum 1 byte) appended after

The prefix check in `seal_approve` verifies this format.

---

## Module: `seal_policies`

Lightweight stateless alternative — no `Allowlist` object is needed. The escrow ID itself is the namespace.

### `seal_approve`

```move
entry fun seal_approve(
    id: vector<u8>,
    escrow_table: &AgenticEscrowTable,
    escrow_id: ID,
    ctx: &TxContext,
)
```

**Three conditions must ALL be true or it aborts `ENoAccess (0)`:**

| # | Check | Detail |
|---|---|---|
| 1 | **Namespace prefix** | `id` must start with `escrow_id.to_bytes()` (32 bytes) |
| 2 | **Audit gate** | `get_is_audited(escrow_table, escrow_id) == true` |
| 3 | **Client only** | `ctx.sender() == get_client(escrow_table, escrow_id)` |

### Encryption Key ID Format (seal_policies)

```
key_id = escrow_id_bytes ++ random_nonce
```

- `escrow_id_bytes` = 32-byte escrow object ID (the `ID` value used as the table key)
- `random_nonce` = any additional bytes appended after

---

## Choosing Between walrus_seal and seal_policies

| | `walrus_seal` | `seal_policies` |
|---|---|---|
| Requires Allowlist object | Yes (shared object) | No |
| Namespace | Allowlist object ID | Escrow ID |
| Blob registration on-chain | Yes (`publish` attaches blob_id) | No |
| Best for | Full provenance tracking | Simple, lightweight sealing |

Use `walrus_seal` when you want an on-chain record that a specific blob belongs to a specific escrow. Use `seal_policies` for a simpler flow with fewer transactions.

---

## Full Transaction Sequence (walrus_seal flow)

```
1. Client calls create_agentic_escrow(... auditor=<auditor_addr> ...)
   → AgenticEscrow created with is_audited=false

2. Main agent does work, uploads blob to Walrus, gets blob_id string

3. Main agent calls agentwave_contract::add_blob_id(escrow_id, table, blob_id)
   → blob_id stored on escrow (optional, for reference)

4. Main agent encrypts blob using Seal with key_id = allowlist_id_bytes ++ nonce
   (Note: must create allowlist first to know the allowlist_id)

4a. Main agent calls walrus_seal::create_allowlist_entry(name, table, escrow_id)
    → Allowlist shared object created
    → Cap transferred to main agent
    → allowlist_id stored on escrow

4b. Main agent calls walrus_seal::publish(allowlist, cap, table, blob_id)
    → blob_id attached to Allowlist as dynamic field

5. Auditor reviews the work off-chain, then calls:
   agentwave_contract::mark_as_audited(escrow_id, table, clock)
   → is_audited = true
   → EscrowAudited event emitted

6. Client requests decryption from Sui Seal service
   → Seal service calls walrus_seal::seal_approve(key_id, table, escrow_id, allowlist)
   → Passes all 3 checks → client receives decryption key → blob decrypted
```

---

## Full Transaction Sequence (seal_policies flow)

```
1. Client calls create_agentic_escrow(... auditor=<auditor_addr> ...)

2. Main agent uploads blob to Walrus, encrypts with key_id = escrow_id_bytes ++ nonce

3. Main agent calls agentwave_contract::add_blob_id(escrow_id, table, blob_id)

4. Auditor calls agentwave_contract::mark_as_audited(escrow_id, table, clock)
   → is_audited = true

5. Client requests decryption from Sui Seal service
   → Seal service calls seal_policies::seal_approve(key_id, table, escrow_id)
   → Passes all 3 checks → client decrypts blob
```

---

## Error Codes Reference

### agentwave_contract

| Constant | Code | Condition |
|---|---|---|
| `ENotAuthorized` | 1 | Caller is not the expected role |
| `EAlreadyAudited` | 12 | `mark_as_audited` called when already `true` |

### walrus_seal

| Constant | Code | Condition |
|---|---|---|
| `EInvalidCap` | 0 | Cap does not match the Allowlist |
| `ENoAccess` | 1 | `seal_approve` failed (any of the 3 checks) |
| `EAllowlistExists` | 3 | Allowlist already created for this escrow |

### seal_policies

| Constant | Code | Condition |
|---|---|---|
| `ENoAccess` | 0 | `seal_approve` failed (any of the 3 checks) |

---

## Security Properties

1. **Only the client can decrypt** — both `walrus_seal` and `seal_policies` check `ctx.sender() == escrow.client` using the live escrow state. No mutable list exists that could be tampered with.

2. **Blob stays sealed until audited** — `is_audited` starts as `false` and can only be set to `true` by the address stored in `escrow.auditor`. No other party can trigger this.

3. **Auditor cannot decrypt** — `mark_as_audited` changes the gate, but the auditor address is never added to any allowlist and is not the client, so the auditor itself cannot pass `seal_approve`.

4. **One allowlist per escrow** — `check_allowlist_is_some` prevents duplicate Allowlist creation for the same escrow.

5. **Namespace scoping** — the prefix check ensures a Seal key issued for one escrow cannot be used to decrypt a blob from a different escrow.
