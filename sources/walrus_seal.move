/// Walrus Seal integration for AgentWave.
///
/// Access model:
///   - The main agent uploads a deliverable blob to Walrus and publishes the blob_id here.
///   - The blob's encryption identity (key ID) is formatted as:
///       [allowlist_object_id_bytes][random_nonce]
///   - The blob is sealed (inaccessible) until the auditor calls `mark_as_audited` on the escrow.
///   - Once `is_audited == true`, the client (and only the client) can call `seal_approve`
///     to obtain decryption access from the Seal service.
module agentwave_contract::walrus_seal;

use agentwave_contract::agentwave_contract::{
    AgenticEscrowTable,
    get_client,
    get_is_audited,
    add_allowlist_id,
    check_allowlist_is_some,
};
use std::string::String;
use sui::dynamic_field as df;

// ===== Error Codes =====
const EInvalidCap: u64 = 0;
const ENoAccess: u64 = 1;
const EAllowlistExists: u64 = 3;

// Sentinel value stored as a dynamic field to track published blobs
const MARKER: u64 = 1;

// ===== Structs =====

/// Shared allowlist object whose object ID forms the encryption namespace.
/// The client address is NOT stored here — it is always read from the escrow
/// itself inside `seal_approve`, so access cannot be widened after creation.
public struct Allowlist has key {
    id: UID,
    name: String,
    /// Records the client address at creation time for off-chain reference only.
    /// `seal_approve` does NOT rely on this field for the access decision.
    client: address,
}

/// Capability held by whoever created the allowlist (typically the main agent).
/// Required to add addresses or publish blobs to the allowlist.
public struct Cap has key {
    id: UID,
    allowlist_id: ID,
}

// ===== Public Functions =====

/// Create an allowlist for the given escrow and add the client to it.
/// Stores the allowlist ID on the escrow so walrus_seal and seal_policies
/// can look it up. Returns a Cap to the caller (main agent).
///
/// Reverts if an allowlist already exists for this escrow.
public fun create_allowlist(
    name: String,
    escrow_table: &mut AgenticEscrowTable,
    escrow_id: ID,
    ctx: &mut TxContext
): Cap {
    assert!(!check_allowlist_is_some(escrow_id, escrow_table), EAllowlistExists);

    let client = get_client(escrow_table, escrow_id);

    let allowlist = Allowlist {
        id: object::new(ctx),
        name,
        client,
    };

    let cap = Cap {
        id: object::new(ctx),
        allowlist_id: object::id(&allowlist),
    };

    // Record the allowlist ID on the escrow for later lookup
    let allowlist_id = object::id(&allowlist);
    transfer::share_object(allowlist);
    add_allowlist_id(escrow_id, escrow_table, allowlist_id, ctx);

    cap
}

/// Entry wrapper — creates allowlist and transfers the Cap to the caller.
entry fun create_allowlist_entry(
    name: String,
    escrow_table: &mut AgenticEscrowTable,
    escrow_id: ID,
    ctx: &mut TxContext
) {
    let cap = create_allowlist(name, escrow_table, escrow_id, ctx);
    transfer::transfer(cap, ctx.sender());
}

/// Publish a Walrus blob by attaching its blob_id as a dynamic field on the allowlist.
/// Requires the matching Cap.
///
/// After publishing, the Seal service will use `seal_approve` to gate decryption
/// until is_audited becomes true.
public fun publish(
    allowlist: &mut Allowlist,
    cap: &Cap,
    _escrow_table: &AgenticEscrowTable,
    blob_id: String,
) {
    assert!(cap.allowlist_id == object::id(allowlist), EInvalidCap);
    df::add(&mut allowlist.id, blob_id, MARKER);
}

/// Returns the namespace prefix for this allowlist (its object ID as bytes).
/// Encryption identities must start with this prefix.
public fun namespace(allowlist: &Allowlist): vector<u8> {
    allowlist.id.to_bytes()
}

// ===== Seal Approve =====

/// Called by the Seal service to decide whether to grant decryption.
///
/// Access is granted when ALL of the following are true:
///   1. The encryption identity `id` starts with this allowlist's namespace.
///   2. The escrow has been marked as audited (`is_audited == true`).
///   3. The caller is exactly the client stored on the escrow — no other address can decrypt.
fun approve_internal(
    caller: address,
    id: vector<u8>,
    escrow_table: &AgenticEscrowTable,
    escrow_id: ID,
    allowlist: &Allowlist,
): bool {
    // 1. Namespace prefix check — ensures this blob belongs to this allowlist
    if (!is_prefix(namespace(allowlist), id)) {
        return false
    };

    // 2. Audit gate — blob stays sealed until auditor approves
    if (!get_is_audited(escrow_table, escrow_id)) {
        return false
    };

    // 3. Client-only check — read the authoritative client address from the escrow,
    //    not from the mutable list, so it can never be bypassed by adding addresses.
    caller == get_client(escrow_table, escrow_id)
}

entry fun seal_approve(
    id: vector<u8>,
    escrow_table: &AgenticEscrowTable,
    escrow_id: ID,
    allowlist: &Allowlist,
    ctx: &TxContext,
) {
    assert!(
        approve_internal(ctx.sender(), id, escrow_table, escrow_id, allowlist),
        ENoAccess
    );
}

// ===== Helpers =====

/// Returns true if `prefix` is a prefix of `word`.
fun is_prefix(prefix: vector<u8>, word: vector<u8>): bool {
    if (prefix.length() > word.length()) {
        return false
    };
    let mut i = 0;
    while (i < prefix.length()) {
        if (prefix[i] != word[i]) {
            return false
        };
        i = i + 1;
    };
    true
}
