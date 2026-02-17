module agentwave_contract::agentwave_contract;

use sui::coin::{Self, Coin};
use sui::balance::{Self, Balance};
use sui::sui::SUI;
use sui::event;
use std::string::String;
use sui::table::{Self, Table};
use sui::table_vec::{Self, TableVec};
use std::option::{Self, Option};

// ===== Error Codes =====
const ENotAuthorized: u64 = 1;
const EInvalidState: u64 = 2;
const EAlreadyPaid: u64 = 3;
const ECannotHireSelf: u64 = 4;
const EInsufficientBalance: u64 = 5;
const ENotInDisputeState: u64 = 6;
const EAgentNotFound: u64 = 7;
const EInsufficientPayment: u64 = 8;        // Payment doesn't cover budget
const ESubAgentsNotPaid: u64 = 9;           // Must pay sub-agents before release
const EBudgetExceeded: u64 = 10;            // Total commitments exceed budget
const EMainAgentPriceExceedsBudget: u64 = 11; // Main agent price > budget
const EAlreadyAudited: u64 = 12;            // Escrow already marked as audited

// ===== Status Constants =====
const STATUS_PENDING: u8 = 0;
const STATUS_ACCEPTED: u8 = 1;
const STATUS_IN_PROGRESS: u8 = 2;
const STATUS_COMPLETED: u8 = 3;
const STATUS_DISPUTED: u8 = 4;
const STATUS_RESOLVED_CLIENT_REFUNDED: u8 = 5;
const STATUS_RESOLVED_MAIN_AGENT_REFUNDED: u8 = 6;
const STATUS_RELEASED: u8 = 7;
const STATUS_CANCELLED: u8 = 8;             // Cancelled by client

// ===== Structs =====

/// Represents a hired sub-agent
public struct HiredAgent has store, copy, drop {
    agent_address: address,
    job: String,
    price: u64,
    paid: bool,
    work_done: bool,
    timestamp: u64,
}

/// Main agentic escrow structure
public struct AgenticEscrow has key, store {
    id: UID,
    client: address,
    custodian: address,
    job_title: String,
    job_description: String,
    job_category: String,
    budget: u64,
    duration: u8,
    balance: Balance<SUI>,
    status: u8,
    main_agent: address,
    main_agent_price: u64,
    main_agent_paid: bool,
    hired_agents: vector<HiredAgent>,
    blob_id: Option<String>,
    created_at: u64,
    // Auditor fields: blob sealed until auditor marks is_audited = true
    auditor: address,
    is_audited: bool,
    allowlist_id: Option<ID>,
}

/// Global table to track all agentic escrows
public struct AgenticEscrowTable has key {
    id: UID,
    escrows: Table<ID, AgenticEscrow>,
    escrow_ids: TableVec<ID>,
    auditor: address,        // Protocol-level auditor address (cannot be overridden by users)
    admin: address,          // Admin who can update the auditor
}

/// Info struct for returning escrow data
public struct AgenticEscrowInfo has drop, store {
    escrow_id: ID,
    job_title: String,
    client: address,
    custodian: address,
    job_description: String,
    job_category: String,
    duration: u8,
    budget: u64,
    current_balance: u64,
    status: u8,
    main_agent: address,
    main_agent_price: u64,
    main_agent_paid: bool,
    total_hired_agents: u64,
    blob_id: Option<String>,
    created_at: u64,
    auditor: address,
    is_audited: bool,
}

// ===== Events =====

public struct AgenticEscrowCreated has copy, drop {
    escrow_id: ID,
    client: address,
    custodian: address,
    main_agent: address,
    budget: u64,
    main_agent_price: u64,
    job_title: String,
    auditor: address,
    timestamp: u64,
}

public struct SubAgentHired has copy, drop {
    escrow_id: ID,
    agent_address: address,
    job: String,
    price: u64,
    hired_by: address,
    timestamp: u64,
}

public struct MainAgentAccepted has copy, drop {
    escrow_id: ID,
    main_agent: address,
    accepted_price: u64,
    timestamp: u64,
}

public struct PaymentReleased has copy, drop {
    escrow_id: ID,
    client: address,
    main_agent: address,
    amount: u64,
    timestamp: u64,
}

public struct SubAgentPaid has copy, drop {
    escrow_id: ID,
    agent_address: address,
    amount: u64,
    timestamp: u64,
}

public struct PlatformFeeCollected has copy, drop {
    escrow_id: ID,
    amount: u64,
    admin_wallet: address,
    timestamp: u64,
}

public struct ClientRefunded has copy, drop {
    escrow_id: ID,
    client: address,
    amount: u64,
    timestamp: u64,
}

public struct MainAgentRefunded has copy, drop {
    escrow_id: ID,
    main_agent: address,
    amount: u64,
    timestamp: u64,
}

public struct SubAgentWorkDoneToggled has copy, drop {
    escrow_id: ID,
    agent_address: address,
    work_done: bool,
    timestamp: u64,
}

public struct EscrowCancelled has copy, drop {
    escrow_id: ID,
    client: address,
    refund_amount: u64,
    timestamp: u64,
}

/// Emitted when auditor marks the escrow as audited, unlocking blob for client
public struct EscrowAudited has copy, drop {
    escrow_id: ID,
    auditor: address,
    timestamp: u64,
}

// ===== Initialization =====

fun init(ctx: &mut TxContext) {
    let escrow_table = AgenticEscrowTable {
        id: object::new(ctx),
        escrows: table::new<ID, AgenticEscrow>(ctx),
        escrow_ids: table_vec::empty(ctx),
        auditor: @custodian_addr,    // Default: custodian is the auditor
        admin: @custodian_addr,      // Default: custodian is the admin
    };
    transfer::share_object(escrow_table);
}

// ===== Public Entry Functions =====

/// Create a new agentic escrow
/// The auditor is always set from the escrow_table (protocol-level, cannot be overridden by users)
public fun create_agentic_escrow(
    escrow_table: &mut AgenticEscrowTable,
    main_agent: address,
    job_title: String,
    job_description: String,
    job_category: String,
    duration: u8,
    budget: u64,
    main_agent_price: u64,
    payment_coin: Coin<SUI>,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
) {
    let client = ctx.sender();
    let timestamp = sui::clock::timestamp_ms(clock);

    // Validate payment covers the budget
    let payment_value = coin::value(&payment_coin);
    assert!(payment_value >= budget, EInsufficientPayment);

    // Validate main_agent_price doesn't exceed budget
    assert!(main_agent_price <= budget, EMainAgentPriceExceedsBudget);

    // Client cannot hire themselves as main agent
    assert!(main_agent != client, ECannotHireSelf);

    let escrow_uid = object::new(ctx);
    let escrow_id = object::uid_to_inner(&escrow_uid);
    let protocol_auditor = escrow_table.auditor;  // Use protocol-level auditor

    let escrow = AgenticEscrow {
        id: escrow_uid,
        client,
        custodian: @custodian_addr,
        job_title,
        job_description,
        job_category,
        duration,
        budget,
        balance: coin::into_balance(payment_coin),
        status: STATUS_PENDING,
        main_agent,
        main_agent_price,
        main_agent_paid: false,
        hired_agents: vector::empty(),
        blob_id: option::none(),
        created_at: timestamp,
        auditor: protocol_auditor,
        is_audited: false,
        allowlist_id: option::none(),
    };

    table_vec::push_back(&mut escrow_table.escrow_ids, escrow_id);
    table::add(&mut escrow_table.escrows, escrow_id, escrow);

    event::emit(AgenticEscrowCreated {
        escrow_id,
        client,
        custodian: @custodian_addr,
        main_agent,
        budget,
        main_agent_price,
        job_title,
        auditor: protocol_auditor,
        timestamp,
    });
}

/// Main agent accepts the job
public fun accept_job(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    assert!(sender == escrow.main_agent, ENotAuthorized);
    assert!(escrow.status == STATUS_PENDING, EInvalidState);

    escrow.status = STATUS_ACCEPTED;

    let timestamp = sui::clock::timestamp_ms(clock);

    event::emit(MainAgentAccepted {
        escrow_id: object::uid_to_inner(&escrow.id),
        main_agent: sender,
        accepted_price: escrow.main_agent_price,
        timestamp,
    });
}

/// Main agent hires a sub-agent
public fun hire_sub_agent(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    agent_address: address,
    job: String,
    price: u64,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    // Only main agent can hire sub-agents
    assert!(sender == escrow.main_agent, ENotAuthorized);

    // Cannot hire yourself
    assert!(agent_address != sender, ECannotHireSelf);

    // Cannot hire the client
    assert!(agent_address != escrow.client, ECannotHireSelf);

    // Can only hire when accepted or in progress
    assert!(
        escrow.status == STATUS_ACCEPTED || escrow.status == STATUS_IN_PROGRESS,
        EInvalidState
    );

    // Calculate total committed amount and validate against budget
    let mut total_sub_agent_cost: u64 = price;
    let mut i = 0;
    while (i < vector::length(&escrow.hired_agents)) {
        let agent = vector::borrow(&escrow.hired_agents, i);
        total_sub_agent_cost = total_sub_agent_cost + agent.price;
        i = i + 1;
    };

    // Ensure total commitments (main agent + all sub-agents) don't exceed budget
    let total_committed = escrow.main_agent_price + total_sub_agent_cost;
    assert!(total_committed <= escrow.budget, EBudgetExceeded);

    let timestamp = sui::clock::timestamp_ms(clock);

    let hired_agent = HiredAgent {
        agent_address,
        job,
        price,
        paid: false,
        work_done: false,
        timestamp,
    };

    vector::push_back(&mut escrow.hired_agents, hired_agent);

    event::emit(SubAgentHired {
        escrow_id: object::uid_to_inner(&escrow.id),
        agent_address,
        job,
        price,
        hired_by: sender,
        timestamp,
    });
}

/// Main agent marks job as in progress
public fun start_job(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    assert!(sender == escrow.main_agent, ENotAuthorized);
    assert!(escrow.status == STATUS_ACCEPTED, EInvalidState);

    escrow.status = STATUS_IN_PROGRESS;
}

/// Main agent completes the job
public fun complete_job(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    assert!(sender == escrow.main_agent, ENotAuthorized);
    assert!(escrow.status == STATUS_IN_PROGRESS, EInvalidState);

    escrow.status = STATUS_COMPLETED;
}

/// Hired sub-agent toggles their work as done
public fun toggle_work_done(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    // Job must be accepted or in progress
    assert!(
        escrow.status == STATUS_ACCEPTED || escrow.status == STATUS_IN_PROGRESS || escrow.status == STATUS_COMPLETED,
        EInvalidState
    );

    // Find the hired agent and toggle work_done
    let mut i = 0;
    let mut found = false;
    while (i < vector::length(&escrow.hired_agents)) {
        let agent = vector::borrow_mut(&mut escrow.hired_agents, i);
        if (agent.agent_address == sender) {
            agent.work_done = !agent.work_done;
            found = true;

            let timestamp = sui::clock::timestamp_ms(clock);

            event::emit(SubAgentWorkDoneToggled {
                escrow_id: object::uid_to_inner(&escrow.id),
                agent_address: sender,
                work_done: agent.work_done,
                timestamp,
            });

            break
        };
        i = i + 1;
    };

    assert!(found, EAgentNotFound);
}

/// Main agent pays a hired sub-agent
public fun pay_sub_agent(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    agent_index: u64,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    // Only main agent can pay sub-agents
    assert!(sender == escrow.main_agent, ENotAuthorized);

    // Job must be completed
    assert!(escrow.status == STATUS_COMPLETED, EInvalidState);

    let agent = vector::borrow_mut(&mut escrow.hired_agents, agent_index);

    // Check if already paid
    assert!(!agent.paid, EAlreadyPaid);

    // Check sufficient balance
    let balance_value = balance::value(&escrow.balance);
    assert!(balance_value >= agent.price, EInsufficientBalance);

    // Mark as paid
    agent.paid = true;

    // Transfer payment
    let payment = coin::take(&mut escrow.balance, agent.price, ctx);
    transfer::public_transfer(payment, agent.agent_address);

    let timestamp = sui::clock::timestamp_ms(clock);

    event::emit(SubAgentPaid {
        escrow_id: object::uid_to_inner(&escrow.id),
        agent_address: agent.agent_address,
        amount: agent.price,
        timestamp,
    });
}

/// Client releases payment to main agent
/// All sub-agents must be paid first
public fun release_payment(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    // Only client can release payment
    assert!(sender == escrow.client, ENotAuthorized);

    // Must be completed
    assert!(escrow.status == STATUS_COMPLETED, EInvalidState);

    // Main agent must not be paid yet
    assert!(!escrow.main_agent_paid, EAlreadyPaid);

    // Ensure all sub-agents have been paid before releasing main agent payment
    let mut i = 0;
    while (i < vector::length(&escrow.hired_agents)) {
        let agent = vector::borrow(&escrow.hired_agents, i);
        assert!(agent.paid, ESubAgentsNotPaid);
        i = i + 1;
    };

    let admin_wallet = @custodian_addr;
    let payment_amount = escrow.main_agent_price;

    // Calculate platform fee (5%)
    let platform_fee = (payment_amount * 5) / 100;
    let main_agent_payment = payment_amount - platform_fee;

    // Extract payment from balance
    let mut payment_balance = balance::split(&mut escrow.balance, payment_amount);

    // Split for platform fee
    let fee_balance = balance::split(&mut payment_balance, platform_fee);
    let fee_coin = coin::from_balance(fee_balance, ctx);

    // Create coin for main agent
    let agent_coin = coin::from_balance(payment_balance, ctx);

    // Transfer platform fee
    transfer::public_transfer(fee_coin, admin_wallet);

    // Transfer payment to main agent
    transfer::public_transfer(agent_coin, escrow.main_agent);

    // Mark as paid
    escrow.main_agent_paid = true;

    // Return remaining balance to client
    let remaining_balance_value = balance::value(&escrow.balance);
    if (remaining_balance_value > 0) {
        let remaining_balance = balance::withdraw_all(&mut escrow.balance);
        let remaining_coin = coin::from_balance(remaining_balance, ctx);
        transfer::public_transfer(remaining_coin, escrow.client);
    };

    // Update status
    escrow.status = STATUS_RELEASED;

    let timestamp = sui::clock::timestamp_ms(clock);

    event::emit(PaymentReleased {
        escrow_id: object::uid_to_inner(&escrow.id),
        client: escrow.client,
        main_agent: escrow.main_agent,
        amount: main_agent_payment,
        timestamp,
    });

    event::emit(PlatformFeeCollected {
        escrow_id: object::uid_to_inner(&escrow.id),
        amount: platform_fee,
        admin_wallet,
        timestamp,
    });
}

/// Client cancels a pending job (before agent accepts)
/// Full refund minus small platform fee (2%)
public fun cancel_pending_job(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    // Only client can cancel
    assert!(sender == escrow.client, ENotAuthorized);

    // Can only cancel if still pending
    assert!(escrow.status == STATUS_PENDING, EInvalidState);

    let admin_wallet = @custodian_addr;
    let total_amount = balance::value(&escrow.balance);

    // Small cancellation fee (2%) to discourage spam
    let platform_fee = (total_amount * 2) / 100;
    let client_refund = total_amount - platform_fee;

    // Extract total balance
    let mut refund_balance = balance::withdraw_all(&mut escrow.balance);

    // Split for platform fee
    let fee_balance = balance::split(&mut refund_balance, platform_fee);
    let fee_coin = coin::from_balance(fee_balance, ctx);

    // Create coin for client refund
    let client_coin = coin::from_balance(refund_balance, ctx);

    // Transfer platform fee
    transfer::public_transfer(fee_coin, admin_wallet);

    // Transfer refund to client
    transfer::public_transfer(client_coin, escrow.client);

    // Update status
    escrow.status = STATUS_CANCELLED;

    let timestamp = sui::clock::timestamp_ms(clock);

    event::emit(EscrowCancelled {
        escrow_id: object::uid_to_inner(&escrow.id),
        client: escrow.client,
        refund_amount: client_refund,
        timestamp,
    });

    event::emit(PlatformFeeCollected {
        escrow_id: object::uid_to_inner(&escrow.id),
        amount: platform_fee,
        admin_wallet,
        timestamp,
    });
}

/// Client or main agent raises a dispute
public fun dispute_job(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    // Only client or main agent can dispute
    assert!(
        sender == escrow.client || sender == escrow.main_agent,
        ENotAuthorized
    );

    // Must be in progress or completed
    assert!(
        escrow.status == STATUS_IN_PROGRESS || escrow.status == STATUS_COMPLETED,
        EInvalidState
    );

    escrow.status = STATUS_DISPUTED;
}

/// Admin refunds client in dispute
public fun refund_client(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    // Only custodian can refund
    assert!(sender == escrow.custodian, ENotAuthorized);

    // Must be disputed
    assert!(escrow.status == STATUS_DISPUTED, ENotInDisputeState);

    let admin_wallet = @custodian_addr;
    let total_amount = balance::value(&escrow.balance);

    // Calculate platform fee (10% - 5% platform + 5% dispute fee)
    let platform_fee = (total_amount * 10) / 100;
    let client_refund = total_amount - platform_fee;

    // Extract total balance
    let mut refund_balance = balance::withdraw_all(&mut escrow.balance);

    // Split for platform fee
    let fee_balance = balance::split(&mut refund_balance, platform_fee);
    let fee_coin = coin::from_balance(fee_balance, ctx);

    // Create coin for client refund
    let client_coin = coin::from_balance(refund_balance, ctx);

    // Transfer platform fee
    transfer::public_transfer(fee_coin, admin_wallet);

    // Transfer refund to client
    transfer::public_transfer(client_coin, escrow.client);

    // Update status
    escrow.status = STATUS_RESOLVED_CLIENT_REFUNDED;

    let timestamp = sui::clock::timestamp_ms(clock);

    event::emit(ClientRefunded {
        escrow_id: object::uid_to_inner(&escrow.id),
        client: escrow.client,
        amount: client_refund,
        timestamp,
    });

    event::emit(PlatformFeeCollected {
        escrow_id: object::uid_to_inner(&escrow.id),
        amount: platform_fee,
        admin_wallet,
        timestamp,
    });
}

/// Admin refunds main agent in dispute
public fun refund_main_agent(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    // Only custodian can refund
    assert!(sender == escrow.custodian, ENotAuthorized);

    // Must be disputed
    assert!(escrow.status == STATUS_DISPUTED, ENotInDisputeState);

    let admin_wallet = @custodian_addr;
    let total_amount = balance::value(&escrow.balance);

    // Calculate platform fee (10%)
    let platform_fee = (total_amount * 10) / 100;
    let agent_refund = total_amount - platform_fee;

    // Extract total balance
    let mut refund_balance = balance::withdraw_all(&mut escrow.balance);

    // Split for platform fee
    let fee_balance = balance::split(&mut refund_balance, platform_fee);
    let fee_coin = coin::from_balance(fee_balance, ctx);

    // Create coin for main agent refund
    let agent_coin = coin::from_balance(refund_balance, ctx);

    // Transfer platform fee
    transfer::public_transfer(fee_coin, admin_wallet);

    // Transfer refund to main agent
    transfer::public_transfer(agent_coin, escrow.main_agent);

    // Update status
    escrow.status = STATUS_RESOLVED_MAIN_AGENT_REFUNDED;

    let timestamp = sui::clock::timestamp_ms(clock);

    event::emit(MainAgentRefunded {
        escrow_id: object::uid_to_inner(&escrow.id),
        main_agent: escrow.main_agent,
        amount: agent_refund,
        timestamp,
    });

    event::emit(PlatformFeeCollected {
        escrow_id: object::uid_to_inner(&escrow.id),
        amount: platform_fee,
        admin_wallet,
        timestamp,
    });
}

/// Add blob ID (Walrus Blob ID string, e.g. "eWo-efsxbEjfNCPLKrCmS4XFW7NqXCgVBnPX4ID00GE")
public fun add_blob_id(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    blob_id: String,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    // Only main agent can add blob ID
    assert!(sender == escrow.main_agent, ENotAuthorized);

    escrow.blob_id = option::some(blob_id);
}

/// Auditor marks the escrow as audited, unlocking the sealed blob for the client
public fun mark_as_audited(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);

    // Only the designated auditor can mark as audited
    assert!(sender == escrow.auditor, ENotAuthorized);

    // Cannot audit twice
    assert!(!escrow.is_audited, EAlreadyAudited);

    escrow.is_audited = true;

    let timestamp = sui::clock::timestamp_ms(clock);

    event::emit(EscrowAudited {
        escrow_id: object::uid_to_inner(&escrow.id),
        auditor: sender,
        timestamp,
    });
}

/// Store the allowlist ID on the escrow (called by walrus_seal module)
public fun add_allowlist_id(
    escrow_id: ID,
    escrow_table: &mut AgenticEscrowTable,
    allowlist_id: ID,
    _ctx: &mut TxContext
) {
    let escrow = table::borrow_mut(&mut escrow_table.escrows, escrow_id);
    escrow.allowlist_id = option::some(allowlist_id);
}

/// ADMIN: Set the protocol auditor address
/// Only the current admin can call this
public fun set_auditor(
    escrow_table: &mut AgenticEscrowTable,
    new_auditor: address,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    assert!(sender == escrow_table.admin, ENotAuthorized);
    escrow_table.auditor = new_auditor;
}

/// ADMIN: Transfer admin rights to a new address
/// Only the current admin can call this
public fun set_admin(
    escrow_table: &mut AgenticEscrowTable,
    new_admin: address,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    assert!(sender == escrow_table.admin, ENotAuthorized);
    escrow_table.admin = new_admin;
}

/// Check whether an allowlist has been created for this escrow
public fun check_allowlist_is_some(
    escrow_id: ID,
    escrow_table: &AgenticEscrowTable,
): bool {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);
    option::is_some(&escrow.allowlist_id)
}

// ===== View Functions =====

/// Get all escrows
public fun get_all_escrows(escrow_table: &AgenticEscrowTable): vector<AgenticEscrowInfo> {
    let mut result = vector::empty<AgenticEscrowInfo>();
    let escrow_ids = &escrow_table.escrow_ids;
    let mut i = 0;

    while (i < table_vec::length(escrow_ids)) {
        let id = *table_vec::borrow(escrow_ids, i);

        if (table::contains(&escrow_table.escrows, id)) {
            let escrow = table::borrow(&escrow_table.escrows, id);

            let escrow_info = AgenticEscrowInfo {
                escrow_id: id,
                job_title: escrow.job_title,
                client: escrow.client,
                custodian: escrow.custodian,
                job_description: escrow.job_description,
                job_category: escrow.job_category,
                duration: escrow.duration,
                budget: escrow.budget,
                current_balance: balance::value(&escrow.balance),
                status: escrow.status,
                main_agent: escrow.main_agent,
                main_agent_price: escrow.main_agent_price,
                main_agent_paid: escrow.main_agent_paid,
                total_hired_agents: vector::length(&escrow.hired_agents),
                blob_id: escrow.blob_id,
                created_at: escrow.created_at,
                auditor: escrow.auditor,
                is_audited: escrow.is_audited,
            };

            vector::push_back(&mut result, escrow_info);
        };

        i = i + 1;
    };

    result
}

/// Get escrows where user is the main agent
public fun get_escrows_as_main_agent(
    escrow_table: &AgenticEscrowTable,
    agent_addr: address
): vector<AgenticEscrowInfo> {
    let mut result = vector::empty<AgenticEscrowInfo>();
    let escrow_ids = &escrow_table.escrow_ids;
    let mut i = 0;

    while (i < table_vec::length(escrow_ids)) {
        let id = *table_vec::borrow(escrow_ids, i);

        if (table::contains(&escrow_table.escrows, id)) {
            let escrow = table::borrow(&escrow_table.escrows, id);

            if (escrow.main_agent == agent_addr) {
                let escrow_info = AgenticEscrowInfo {
                    escrow_id: id,
                    job_title: escrow.job_title,
                    client: escrow.client,
                    custodian: escrow.custodian,
                    job_description: escrow.job_description,
                    job_category: escrow.job_category,
                    duration: escrow.duration,
                    budget: escrow.budget,
                    current_balance: balance::value(&escrow.balance),
                    status: escrow.status,
                    main_agent: escrow.main_agent,
                    main_agent_price: escrow.main_agent_price,
                    main_agent_paid: escrow.main_agent_paid,
                    total_hired_agents: vector::length(&escrow.hired_agents),
                    blob_id: escrow.blob_id,
                    created_at: escrow.created_at,
                    auditor: escrow.auditor,
                    is_audited: escrow.is_audited,
                };

                vector::push_back(&mut result, escrow_info);
            };
        };

        i = i + 1;
    };

    result
}

/// Get escrows where user is a hired sub-agent
public fun get_escrows_as_sub_agent(
    escrow_table: &AgenticEscrowTable,
    agent_addr: address
): vector<AgenticEscrowInfo> {
    let mut result = vector::empty<AgenticEscrowInfo>();
    let escrow_ids = &escrow_table.escrow_ids;
    let mut i = 0;

    while (i < table_vec::length(escrow_ids)) {
        let id = *table_vec::borrow(escrow_ids, i);

        if (table::contains(&escrow_table.escrows, id)) {
            let escrow = table::borrow(&escrow_table.escrows, id);

            let mut j = 0;
            let mut is_hired = false;

            while (j < vector::length(&escrow.hired_agents)) {
                let agent = vector::borrow(&escrow.hired_agents, j);
                if (agent.agent_address == agent_addr) {
                    is_hired = true;
                    break
                };
                j = j + 1;
            };

            if (is_hired) {
                let escrow_info = AgenticEscrowInfo {
                    escrow_id: id,
                    job_title: escrow.job_title,
                    client: escrow.client,
                    custodian: escrow.custodian,
                    job_description: escrow.job_description,
                    job_category: escrow.job_category,
                    duration: escrow.duration,
                    budget: escrow.budget,
                    current_balance: balance::value(&escrow.balance),
                    status: escrow.status,
                    main_agent: escrow.main_agent,
                    main_agent_price: escrow.main_agent_price,
                    main_agent_paid: escrow.main_agent_paid,
                    total_hired_agents: vector::length(&escrow.hired_agents),
                    blob_id: escrow.blob_id,
                    created_at: escrow.created_at,
                    auditor: escrow.auditor,
                    is_audited: escrow.is_audited,
                };

                vector::push_back(&mut result, escrow_info);
            };
        };

        i = i + 1;
    };

    result
}

/// Get escrows where user is the client
public fun get_escrows_as_client(
    escrow_table: &AgenticEscrowTable,
    client_addr: address
): vector<AgenticEscrowInfo> {
    let mut result = vector::empty<AgenticEscrowInfo>();
    let escrow_ids = &escrow_table.escrow_ids;
    let mut i = 0;

    while (i < table_vec::length(escrow_ids)) {
        let id = *table_vec::borrow(escrow_ids, i);

        if (table::contains(&escrow_table.escrows, id)) {
            let escrow = table::borrow(&escrow_table.escrows, id);

            if (escrow.client == client_addr) {
                let escrow_info = AgenticEscrowInfo {
                    escrow_id: id,
                    job_title: escrow.job_title,
                    client: escrow.client,
                    custodian: escrow.custodian,
                    job_description: escrow.job_description,
                    job_category: escrow.job_category,
                    duration: escrow.duration,
                    budget: escrow.budget,
                    current_balance: balance::value(&escrow.balance),
                    status: escrow.status,
                    main_agent: escrow.main_agent,
                    main_agent_price: escrow.main_agent_price,
                    main_agent_paid: escrow.main_agent_paid,
                    total_hired_agents: vector::length(&escrow.hired_agents),
                    blob_id: escrow.blob_id,
                    created_at: escrow.created_at,
                    auditor: escrow.auditor,
                    is_audited: escrow.is_audited,
                };

                vector::push_back(&mut result, escrow_info);
            };
        };

        i = i + 1;
    };

    result
}

/// Get all pending escrows
public fun get_all_pending_escrows(escrow_table: &AgenticEscrowTable): vector<AgenticEscrowInfo> {
    let mut result = vector::empty<AgenticEscrowInfo>();
    let escrow_ids = &escrow_table.escrow_ids;
    let mut i = 0;

    while (i < table_vec::length(escrow_ids)) {
        let id = *table_vec::borrow(escrow_ids, i);

        if (table::contains(&escrow_table.escrows, id)) {
            let escrow = table::borrow(&escrow_table.escrows, id);

            if (escrow.status == STATUS_PENDING) {
                let escrow_info = AgenticEscrowInfo {
                    escrow_id: id,
                    job_title: escrow.job_title,
                    client: escrow.client,
                    custodian: escrow.custodian,
                    job_description: escrow.job_description,
                    job_category: escrow.job_category,
                    duration: escrow.duration,
                    budget: escrow.budget,
                    current_balance: balance::value(&escrow.balance),
                    status: escrow.status,
                    main_agent: escrow.main_agent,
                    main_agent_price: escrow.main_agent_price,
                    main_agent_paid: escrow.main_agent_paid,
                    total_hired_agents: vector::length(&escrow.hired_agents),
                    blob_id: escrow.blob_id,
                    created_at: escrow.created_at,
                    auditor: escrow.auditor,
                    is_audited: escrow.is_audited,
                };

                vector::push_back(&mut result, escrow_info);
            };
        };

        i = i + 1;
    };

    result
}

/// Get all disputed escrows
public fun get_all_disputed_escrows(escrow_table: &AgenticEscrowTable): vector<AgenticEscrowInfo> {
    let mut result = vector::empty<AgenticEscrowInfo>();
    let escrow_ids = &escrow_table.escrow_ids;
    let mut i = 0;

    while (i < table_vec::length(escrow_ids)) {
        let id = *table_vec::borrow(escrow_ids, i);

        if (table::contains(&escrow_table.escrows, id)) {
            let escrow = table::borrow(&escrow_table.escrows, id);

            if (escrow.status == STATUS_DISPUTED) {
                let escrow_info = AgenticEscrowInfo {
                    escrow_id: id,
                    job_title: escrow.job_title,
                    client: escrow.client,
                    custodian: escrow.custodian,
                    job_description: escrow.job_description,
                    job_category: escrow.job_category,
                    duration: escrow.duration,
                    budget: escrow.budget,
                    current_balance: balance::value(&escrow.balance),
                    status: escrow.status,
                    main_agent: escrow.main_agent,
                    main_agent_price: escrow.main_agent_price,
                    main_agent_paid: escrow.main_agent_paid,
                    total_hired_agents: vector::length(&escrow.hired_agents),
                    blob_id: escrow.blob_id,
                    created_at: escrow.created_at,
                    auditor: escrow.auditor,
                    is_audited: escrow.is_audited,
                };

                vector::push_back(&mut result, escrow_info);
            };
        };

        i = i + 1;
    };

    result
}

/// Get single escrow by ID
public fun get_escrow_by_id(
    escrow_table: &AgenticEscrowTable,
    escrow_id: ID
): AgenticEscrowInfo {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);

    AgenticEscrowInfo {
        escrow_id,
        job_title: escrow.job_title,
        client: escrow.client,
        custodian: escrow.custodian,
        job_description: escrow.job_description,
        job_category: escrow.job_category,
        duration: escrow.duration,
        budget: escrow.budget,
        current_balance: balance::value(&escrow.balance),
        status: escrow.status,
        main_agent: escrow.main_agent,
        main_agent_price: escrow.main_agent_price,
        main_agent_paid: escrow.main_agent_paid,
        total_hired_agents: vector::length(&escrow.hired_agents),
        blob_id: escrow.blob_id,
        created_at: escrow.created_at,
        auditor: escrow.auditor,
        is_audited: escrow.is_audited,
    }
}

/// Get hired agents for an escrow
public fun get_hired_agents(
    escrow_table: &AgenticEscrowTable,
    escrow_id: ID
): vector<HiredAgent> {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);
    escrow.hired_agents
}

/// Get blob ID (returns Walrus Blob ID string)
public fun get_blob_id(
    escrow_id: ID,
    escrow_table: &AgenticEscrowTable
): Option<String> {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);
    escrow.blob_id
}

/// Check if blob ID exists
public fun check_blob_id_is_some(
    escrow_id: ID,
    escrow_table: &AgenticEscrowTable
): bool {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);
    option::is_some(&escrow.blob_id)
}

/// Get status
public fun get_status(escrow_table: &AgenticEscrowTable, escrow_id: ID): u8 {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);
    escrow.status
}

/// Get client address
public fun get_client(escrow_table: &AgenticEscrowTable, escrow_id: ID): address {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);
    escrow.client
}

/// Get main agent address
public fun get_main_agent(escrow_table: &AgenticEscrowTable, escrow_id: ID): address {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);
    escrow.main_agent
}

/// Get auditor address for a specific escrow
public fun get_auditor(escrow_table: &AgenticEscrowTable, escrow_id: ID): address {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);
    escrow.auditor
}

/// Get protocol-level auditor address
public fun get_protocol_auditor(escrow_table: &AgenticEscrowTable): address {
    escrow_table.auditor
}

/// Get admin address
public fun get_admin(escrow_table: &AgenticEscrowTable): address {
    escrow_table.admin
}

/// Get is_audited flag — true means blob is unlocked for client to decrypt
public fun get_is_audited(escrow_table: &AgenticEscrowTable, escrow_id: ID): bool {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);
    escrow.is_audited
}

/// Get escrow IDs
public fun get_ids(table_ids: &AgenticEscrowTable): &TableVec<ID> {
    &table_ids.escrow_ids
}

/// Helper to check if all sub-agents are paid
public fun all_sub_agents_paid(
    escrow_table: &AgenticEscrowTable,
    escrow_id: ID
): bool {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);
    let mut i = 0;
    while (i < vector::length(&escrow.hired_agents)) {
        let agent = vector::borrow(&escrow.hired_agents, i);
        if (!agent.paid) {
            return false
        };
        i = i + 1;
    };
    true
}

/// Get total committed amount (main agent + sub-agents)
public fun get_total_committed(
    escrow_table: &AgenticEscrowTable,
    escrow_id: ID
): u64 {
    let escrow = table::borrow(&escrow_table.escrows, escrow_id);
    let mut total = escrow.main_agent_price;
    let mut i = 0;
    while (i < vector::length(&escrow.hired_agents)) {
        let agent = vector::borrow(&escrow.hired_agents, i);
        total = total + agent.price;
        i = i + 1;
    };
    total
}

// ===== Test Functions =====

#[test_only]
public fun init_for_test(ctx: &mut TxContext) {
    init(ctx)
}
