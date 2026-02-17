/// Seal policies for AgentWave — lightweight policy checker.
///
/// This module provides a stateless `seal_approve` entry point that the Seal
/// service can call without requiring an Allowlist object.
///
/// Access model (same as walrus_seal but without the Allowlist object):
///   - Encryption identity format: [escrow_id_bytes][random_nonce]
///   - The blob is sealed until `is_audited == true` on the escrow.
///   - Once audited, only the client of that escrow can decrypt.
///
/// Use this module when you want to seal blobs using the escrow ID directly
/// as the namespace, without maintaining a separate Allowlist shared object.
module agentwave_contract::seal_policies;

use agentwave_contract::agentwave_contract::{
    AgenticEscrowTable,
    get_client,
    get_is_audited,
};

// ===== Error Codes =====
const ENoAccess: u64 = 0;

// ===== Seal Approve =====

/// Internal approval logic.
///
/// Grants decryption when ALL of the following hold:
///   1. The encryption identity `id` starts with the escrow ID bytes (namespace).
///   2. The escrow has been marked as audited (`is_audited == true`).
///   3. The caller is the client of the escrow.
fun approve_internal(
    caller: address,
    id: vector<u8>,
    escrow_table: &AgenticEscrowTable,
    escrow_id: ID,
): bool {
    // 1. Namespace check — encryption identity must be scoped to this escrow
    let namespace = escrow_id.to_bytes();
    if (!is_prefix(namespace, id)) {
        return false
    };

    // 2. Audit gate — blob stays sealed until auditor approves
    if (!get_is_audited(escrow_table, escrow_id)) {
        return false
    };

    // 3. Only the client can decrypt the deliverable
    caller == get_client(escrow_table, escrow_id)
}

/// Entry point called by the Seal service.
/// Aborts with ENoAccess if approval conditions are not met.
entry fun seal_approve(
    id: vector<u8>,
    escrow_table: &AgenticEscrowTable,
    escrow_id: ID,
    ctx: &TxContext,
) {
    assert!(
        approve_internal(ctx.sender(), id, escrow_table, escrow_id),
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
