module agentwave_contract::agentwave_profile;

use std::string::String;
use sui::event;
use sui::table::{Self, Table};
use sui::table_vec::{Self, TableVec};

// Error codes
const EProfileAlreadyExists: u64 = 100;
const EProfileNotFound: u64 = 101;
const ENotAuthorized: u64 = 102;
const EInvalidRating: u64 = 103;
const EAdminCapMismatch: u64 = 104;
const EAdminExists: u64 = 105;
const EAdminNotFound: u64 = 106;

/// Struct to hold AI agent profile information
public struct AgentProfile has store {
    name: String,
    avatar: String,
    owner_address: address,
    capabilities: vector<String>,
    description: String,
    rating: u64, // Rating out of 100
    total_reviews: u64,
    completed_tasks: u64,
    created_at: u64,
    model_type: String, // e.g., "GPT-4", "Claude", "Custom"
    is_active: bool,
}

public struct AdminCap has key {
    id: UID,
}

/// Global registry to track all AI agent profiles
public struct AgentRegistry has key {
    id: UID,
    profiles: Table<address, AgentProfile>,
    profile_addresses: TableVec<address>,
    admin_addresses: vector<address>,
}

// Events
public struct AgentProfileCreated has copy, drop {
    name: String,
    owner: address,
    timestamp: u64,
}

public struct AgentProfileUpdated has copy, drop {
    owner: address,
    timestamp: u64,
}

public struct AgentStatusChanged has copy, drop {
    owner: address,
    is_active: bool,
    timestamp: u64,
}

/// Initialize the AI agent registry (call once on deployment)
fun init(ctx: &mut TxContext) {
    let sender = ctx.sender();
    let registry = AgentRegistry {
        id: object::new(ctx),
        profiles: table::new<address, AgentProfile>(ctx),
        profile_addresses: table_vec::empty(ctx),
        admin_addresses: vector[sender],
    };
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };

    transfer::share_object(registry);
    transfer::transfer(admin_cap, sender);
}

/// Registers a new AI agent profile
public fun register_agent_profile(
    registry: &mut AgentRegistry,
    name: String,
    avatar: String,
    capabilities: vector<String>,
    description: String,
    model_type: String,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext,
) {
    let owner = ctx.sender();

    assert!(!table::contains(&registry.profiles, owner), EProfileAlreadyExists);

    let timestamp = sui::clock::timestamp_ms(clock);

    let profile = AgentProfile {
        name,
        avatar,
        owner_address: owner,
        capabilities,
        description,
        rating: 0,
        total_reviews: 0,
        completed_tasks: 0,
        created_at: timestamp,
        model_type,
        is_active: true,
    };

    table::add(&mut registry.profiles, owner, profile);
    table_vec::push_back(&mut registry.profile_addresses, owner);

    // Emit event
    event::emit(AgentProfileCreated {
        name,
        owner,
        timestamp,
    });
}

/// Updates an existing AI agent profile
public fun update_agent_profile(
    registry: &mut AgentRegistry,
    mut name: Option<String>,
    mut avatar: Option<String>,
    mut capabilities: Option<vector<String>>,
    mut description: Option<String>,
    mut model_type: Option<String>,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext,
) {
    let owner = ctx.sender();

    assert!(table::contains(&registry.profiles, owner), EProfileNotFound);

    let profile = table::borrow_mut(&mut registry.profiles, owner);

    // Verify that the sender is the profile owner
    assert!(profile.owner_address == owner, ENotAuthorized);

    // Update profile fields only if provided
    if (option::is_some(&name)) {
        profile.name = option::extract(&mut name);
    };

    if (option::is_some(&avatar)) {
        profile.avatar = option::extract(&mut avatar);
    };

    if (option::is_some(&capabilities)) {
        profile.capabilities = option::extract(&mut capabilities);
    };

    if (option::is_some(&description)) {
        profile.description = option::extract(&mut description);
    };

    if (option::is_some(&model_type)) {
        profile.model_type = option::extract(&mut model_type);
    };

    let timestamp = sui::clock::timestamp_ms(clock);

    // Emit event
    event::emit(AgentProfileUpdated {
        owner,
        timestamp,
    });
}

/// Toggle agent active status
public fun toggle_agent_status(
    registry: &mut AgentRegistry,
    clock: &sui::clock::Clock,
    ctx: &mut TxContext,
) {
    let owner = ctx.sender();

    assert!(table::contains(&registry.profiles, owner), EProfileNotFound);

    let profile = table::borrow_mut(&mut registry.profiles, owner);

    // Verify that the sender is the profile owner
    assert!(profile.owner_address == owner, ENotAuthorized);

    // Toggle status
    profile.is_active = !profile.is_active;

    let timestamp = sui::clock::timestamp_ms(clock);

    // Emit event
    event::emit(AgentStatusChanged {
        owner,
        is_active: profile.is_active,
        timestamp,
    });
}

/// Update agent statistics (called by escrow contract)
public(package) fun update_agent_stats(
    registry: &mut AgentRegistry,
    agent_address: address,
    new_rating: u64,
) {
    assert!(table::contains(&registry.profiles, agent_address), EProfileNotFound);
    assert!(new_rating <= 100, EInvalidRating);

    let profile = table::borrow_mut(&mut registry.profiles, agent_address);

    // Update rating (weighted average)
    let total_reviews = profile.total_reviews;
    if (total_reviews == 0) {
        profile.rating = new_rating;
    } else {
        let current_total = profile.rating * total_reviews;
        profile.rating = (current_total + new_rating) / (total_reviews + 1);
    };

    profile.total_reviews = total_reviews + 1;
    profile.completed_tasks = profile.completed_tasks + 1;
}

/// Check if user has an agent profile
public fun check_agent_profile(registry: &AgentRegistry, agent_addr: address): bool {
    table::contains(&registry.profiles, agent_addr)
}

/// Get single agent profile
public fun get_agent_profile(
    registry: &AgentRegistry,
    owner_addr: address,
): (String, String, vector<String>, String, u64, u64, u64, u64, String, bool) {
    let profile = table::borrow(&registry.profiles, owner_addr);
    (
        profile.avatar,
        profile.name,
        profile.capabilities,
        profile.description,
        profile.rating,
        profile.total_reviews,
        profile.completed_tasks,
        profile.created_at,
        profile.model_type,
        profile.is_active,
    )
}

/// Profile info struct for returning data
public struct AgentProfileInfo has copy, drop, store {
    owner: address,
    avatar: String,
    name: String,
    capabilities: vector<String>,
    description: String,
    rating: u64,
    total_reviews: u64,
    completed_tasks: u64,
    created_at: u64,
    model_type: String,
    is_active: bool,
}

/// Get all agent profiles
public fun get_all_agent_profiles(registry: &AgentRegistry): vector<AgentProfileInfo> {
    let mut results = vector::empty<AgentProfileInfo>();
    let mut i = 0;
    let addresses = &registry.profile_addresses;

    while (i < table_vec::length(addresses)) {
        let addr = *table_vec::borrow(addresses, i);
        if (table::contains(&registry.profiles, addr)) {
            let profile = table::borrow(&registry.profiles, addr);
            let profile_info = AgentProfileInfo {
                owner: addr,
                avatar: profile.avatar,
                name: profile.name,
                capabilities: profile.capabilities,
                description: profile.description,
                rating: profile.rating,
                total_reviews: profile.total_reviews,
                completed_tasks: profile.completed_tasks,
                created_at: profile.created_at,
                model_type: profile.model_type,
                is_active: profile.is_active,
            };
            vector::push_back(&mut results, profile_info);
        };
        i = i + 1;
    };

    results
}

/// Get active agent profiles only
public fun get_active_agent_profiles(registry: &AgentRegistry): vector<AgentProfileInfo> {
    let mut results = vector::empty<AgentProfileInfo>();
    let mut i = 0;
    let addresses = &registry.profile_addresses;

    while (i < table_vec::length(addresses)) {
        let addr = *table_vec::borrow(addresses, i);
        if (table::contains(&registry.profiles, addr)) {
            let profile = table::borrow(&registry.profiles, addr);
            if (profile.is_active) {
                let profile_info = AgentProfileInfo {
                    owner: addr,
                    avatar: profile.avatar,
                    name: profile.name,
                    capabilities: profile.capabilities,
                    description: profile.description,
                    rating: profile.rating,
                    total_reviews: profile.total_reviews,
                    completed_tasks: profile.completed_tasks,
                    created_at: profile.created_at,
                    model_type: profile.model_type,
                    is_active: profile.is_active,
                };
                vector::push_back(&mut results, profile_info);
            };
        };
        i = i + 1;
    };

    results
}

/// Get paginated agent profiles
public fun get_agent_profiles_paginated(
    registry: &AgentRegistry,
    start: u64,
    limit: u64,
): vector<AgentProfileInfo> {
    let mut results = vector::empty<AgentProfileInfo>();
    let total = table_vec::length(&registry.profile_addresses);
    let end = if (start + limit > total) { total } else { start + limit };

    let mut i = start;
    while (i < end) {
        let addr = *table_vec::borrow(&registry.profile_addresses, i);
        if (table::contains(&registry.profiles, addr)) {
            let profile = table::borrow(&registry.profiles, addr);
            vector::push_back(
                &mut results,
                AgentProfileInfo {
                    owner: addr,
                    avatar: profile.avatar,
                    name: profile.name,
                    capabilities: profile.capabilities,
                    description: profile.description,
                    rating: profile.rating,
                    total_reviews: profile.total_reviews,
                    completed_tasks: profile.completed_tasks,
                    created_at: profile.created_at,
                    model_type: profile.model_type,
                    is_active: profile.is_active,
                },
            );
        };
        i = i + 1;
    };

    results
}

/// Admin functions
public fun add_admin(
    registry: &mut AgentRegistry,
    _admin_cap: &AdminCap,
    new_admin: address,
    ctx: &mut TxContext,
) {
    let sender = ctx.sender();
    let custodian = @custodian_addr;

    assert!(sender == custodian, EAdminCapMismatch);

    let mut i = 0;
    while (i < vector::length(&registry.admin_addresses)) {
        let admin_addr = *vector::borrow(&registry.admin_addresses, i);
        assert!(admin_addr != new_admin, EAdminExists);
        i = i + 1;
    };

    vector::push_back(&mut registry.admin_addresses, new_admin);
}

public fun remove_admin(
    registry: &mut AgentRegistry,
    _admin_cap: &AdminCap,
    admin_to_remove: address,
    ctx: &mut TxContext,
) {
    let sender = ctx.sender();
    let custodian = @custodian_addr;

    assert!(sender == custodian, EAdminCapMismatch);

    let mut i = 0;
    while (i < vector::length(&registry.admin_addresses)) {
        let admin_addr = *vector::borrow(&registry.admin_addresses, i);

        if (admin_addr == admin_to_remove) {
            vector::remove(&mut registry.admin_addresses, i);
            return
        };
        i = i + 1;
    };
}

public fun check_admin(registry: &AgentRegistry, admin_address: address): bool {
    let admins_len = vector::length(&registry.admin_addresses);
    let mut i = 0;

    while (i < admins_len) {
        let admin = vector::borrow(&registry.admin_addresses, i);
        if (*admin == admin_address) {
            return true
        };
        i = i + 1;
    };

    false
}

public fun get_admins(registry: &AgentRegistry): vector<address> {
    registry.admin_addresses
}

#[test_only]
public fun init_for_test(ctx: &mut TxContext) {
    init(ctx)
}
