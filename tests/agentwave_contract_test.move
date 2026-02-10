#[test_only]
module agentwave_contract::agentwave_contract_test;

use agentwave_contract::agentwave_profile::{Self, AgentRegistry, AdminCap};
use agentwave_contract::agentwave_contract::{Self, AgenticEscrowTable};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario;
use sui::test_scenario::take_shared;
use sui::clock;
use std::string::String;
use std::debug;
use sui::test_scenario::take_from_address;
use sui::table_vec::{Self, TableVec};

#[test]
fun test_agent_profile_registration() {
    let admin = @0xA;
    let agent1 = @0xB;
    let agent2 = @0xC;
    let client = @0xD;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, admin);
    {
        agentwave_profile::init_for_test(test_scenario::ctx(scenario));
    }; 

    // Register first agent
    test_scenario::next_tx(scenario, agent1);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"DataBot AI".to_string(),
            b"https://avatar.url/databot".to_string(),
            vector<String>[b"data_analysis".to_string(), b"machine_learning".to_string()],
            b"Specialized in data analytics and ML tasks".to_string(),
            b"GPT-4".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Register second agent
    test_scenario::next_tx(scenario, agent2);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"CodeHelper AI".to_string(),
            b"https://avatar.url/codehelper".to_string(),
            vector<String>[b"coding".to_string(), b"debugging".to_string()],
            b"Expert in software development".to_string(),
            b"Claude".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Register client
    test_scenario::next_tx(scenario, client);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"TaskMaster AI".to_string(),
            b"https://avatar.url/taskmaster".to_string(),
            vector<String>[b"task_management".to_string()],
            b"Manages and delegates tasks".to_string(),
            b"Custom".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Verify agent profiles
    test_scenario::next_tx(scenario, agent1);
    {
        let registry: AgentRegistry = take_shared(scenario);

        let (avatar, name, capabilities, description, rating, total_reviews, completed_tasks, created_at, model_type, is_active) = 
            agentwave_profile::get_agent_profile(&registry, agent1);

        debug::print(&b"Agent Profile:".to_string());
        debug::print(&avatar);
        debug::print(&name);
        debug::print(&capabilities);
        debug::print(&description);
        debug::print(&rating);
        debug::print(&total_reviews);
        debug::print(&completed_tasks);
        debug::print(&created_at);
        debug::print(&model_type);
        debug::print(&is_active);
        
        test_scenario::return_shared(registry);
    };

    // Get all profiles
    test_scenario::next_tx(scenario, agent1);
    {
        let registry: AgentRegistry = take_shared(scenario);

        let all_profiles = agentwave_profile::get_all_agent_profiles(&registry);
        debug::print(&b"All Agent Profiles:".to_string());
        debug::print(&all_profiles);
        
        test_scenario::return_shared(registry);
    };
      
    test_scenario::end(scenario_val);
}

#[test]
fun test_complete_escrow_workflow() {
    let admin = @0xA;
    let client = @0xD;
    let main_agent = @0xB;
    let sub_agent = @0xC;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    
    // Initialize contracts
    test_scenario::next_tx(scenario, admin);
    {
        agentwave_contract::init_for_test(test_scenario::ctx(scenario));
    }; 

    test_scenario::next_tx(scenario, admin);
    {
        agentwave_profile::init_for_test(test_scenario::ctx(scenario));
    }; 

    // Register main agent
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"MainAgent AI".to_string(),
            b"https://avatar.url/main".to_string(),
            vector<String>[b"project_management".to_string()],
            b"Manages complex projects".to_string(),
            b"Claude".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Register sub agent
    test_scenario::next_tx(scenario, sub_agent);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"SubAgent AI".to_string(),
            b"https://avatar.url/sub".to_string(),
            vector<String>[b"data_processing".to_string()],
            b"Processes data efficiently".to_string(),
            b"GPT-4".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Register client
    test_scenario::next_tx(scenario, client);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"Client AI".to_string(),
            b"https://avatar.url/client".to_string(),
            vector<String>[b"business_operations".to_string()],
            b"Manages business operations".to_string(),
            b"Custom".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Create escrow
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let payment: Coin<SUI> = coin::mint_for_testing(100_000_000_000, test_scenario::ctx(scenario));

        agentwave_contract::create_agentic_escrow(
            &mut escrow_table,
            main_agent,
            b"AI Data Analysis Project".to_string(),
            b"Analyze customer data and provide insights".to_string(),
            b"Data Analytics".to_string(),
            24,
            100_000_000_000,
            80_000_000_000,
            payment,
            &clock,
            test_scenario::ctx(scenario)
        );
    
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Main agent accepts job
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::accept_job(
            escrow_id,
            &mut escrow_table,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Main agent hires sub-agent
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::hire_sub_agent(
            escrow_id,
            &mut escrow_table,
            sub_agent,
            b"Data preprocessing and cleaning".to_string(),
            20_000_000_000,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Start job
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::start_job(
            escrow_id,
            &mut escrow_table,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(escrow_table);
    };

    // Complete job
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::complete_job(
            escrow_id,
            &mut escrow_table,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(escrow_table);
    };

    // Pay sub-agent
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::pay_sub_agent(
            escrow_id,
            &mut escrow_table,
            0, // First sub-agent
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Release payment to main agent
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::release_payment(
            escrow_id,
            &mut escrow_table,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Verify admin received platform fee
    test_scenario::next_tx(scenario, admin);
    {
        debug::print(&b"Checking if admin received platform fee...".to_string());
        
        if (!test_scenario::has_most_recent_for_address<Coin<SUI>>(admin)) {
            debug::print(&b"ERROR: Admin has NO coin!".to_string());
            abort 999
        };
        
        let coin = test_scenario::take_from_address<Coin<SUI>>(scenario, admin);
        let value = coin.value();
        debug::print(&b"Platform fee received:".to_string());
        debug::print(&value);
    
        test_scenario::return_to_address(admin, coin);
    };

    // Verify sub-agent received payment
    test_scenario::next_tx(scenario, sub_agent);
    {
        debug::print(&b"Checking if sub-agent received payment...".to_string());
        
        if (!test_scenario::has_most_recent_for_address<Coin<SUI>>(sub_agent)) {
            debug::print(&b"ERROR: Sub-agent has NO coin!".to_string());
            abort 999
        };
        
        let coin = test_scenario::take_from_address<Coin<SUI>>(scenario, sub_agent);
        let value = coin.value();
        debug::print(&b"Sub-agent payment received:".to_string());
        debug::print(&value);
    
        test_scenario::return_to_address(sub_agent, coin);
    };

    // Verify main agent received payment
    test_scenario::next_tx(scenario, main_agent);
    {
        debug::print(&b"Checking if main agent received payment...".to_string());
        
        if (!test_scenario::has_most_recent_for_address<Coin<SUI>>(main_agent)) {
            debug::print(&b"ERROR: Main agent has NO coin!".to_string());
            abort 999
        };
        
        let coin = test_scenario::take_from_address<Coin<SUI>>(scenario, main_agent);
        let value = coin.value();
        debug::print(&b"Main agent payment received:".to_string());
        debug::print(&value);
    
        test_scenario::return_to_address(main_agent, coin);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_client_refund_dispute() {
    let admin = @0xA;
    let client = @0xD;
    let main_agent = @0xB;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, admin);
    {
        agentwave_contract::init_for_test(test_scenario::ctx(scenario));
    }; 

    test_scenario::next_tx(scenario, admin);
    {
        agentwave_profile::init_for_test(test_scenario::ctx(scenario));
    }; 

    // Register main agent
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"Agent AI".to_string(),
            b"https://avatar.url".to_string(),
            vector<String>[b"general".to_string()],
            b"General purpose AI".to_string(),
            b"GPT-4".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Register client
    test_scenario::next_tx(scenario, client);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"Client AI".to_string(),
            b"https://avatar.url".to_string(),
            vector<String>[b"business".to_string()],
            b"Business AI".to_string(),
            b"Custom".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Create escrow
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let payment: Coin<SUI> = coin::mint_for_testing(100_000_000_000, test_scenario::ctx(scenario));

        agentwave_contract::create_agentic_escrow(
            &mut escrow_table,
            main_agent,
            b"Test Project".to_string(),
            b"Testing dispute resolution".to_string(),
            b"Testing".to_string(),
            24,
            100_000_000_000,
            80_000_000_000,
            payment,
            &clock,
            test_scenario::ctx(scenario)
        );
    
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Accept job
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::accept_job(
            escrow_id,
            &mut escrow_table,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Start job
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::start_job(
            escrow_id,
            &mut escrow_table,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(escrow_table);
    };

    // Raise dispute
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::dispute_job(
            escrow_id,
            &mut escrow_table,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(escrow_table);
    };

    // Admin refunds client
    test_scenario::next_tx(scenario, admin);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::refund_client(
            escrow_id,
            &mut escrow_table,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Verify client received refund
    test_scenario::next_tx(scenario, client);
    {
        debug::print(&b"Checking if client received refund...".to_string());
        
        if (!test_scenario::has_most_recent_for_address<Coin<SUI>>(client)) {
            debug::print(&b"ERROR: Client has NO coin!".to_string());
            abort 999
        };
        
        let coin = test_scenario::take_from_address<Coin<SUI>>(scenario, client);
        let value = coin.value();
        debug::print(&b"Client refund received:".to_string());
        debug::print(&value);
    
        test_scenario::return_to_address(client, coin);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_main_agent_refund_dispute() {
    let admin = @0xA;
    let client = @0xD;
    let main_agent = @0xB;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, admin);
    {
        agentwave_contract::init_for_test(test_scenario::ctx(scenario));
    }; 

    test_scenario::next_tx(scenario, admin);
    {
        agentwave_profile::init_for_test(test_scenario::ctx(scenario));
    }; 

    // Register main agent
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"Agent AI".to_string(),
            b"https://avatar.url".to_string(),
            vector<String>[b"general".to_string()],
            b"General purpose AI".to_string(),
            b"GPT-4".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Register client
    test_scenario::next_tx(scenario, client);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"Client AI".to_string(),
            b"https://avatar.url".to_string(),
            vector<String>[b"business".to_string()],
            b"Business AI".to_string(),
            b"Custom".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Create escrow
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let payment: Coin<SUI> = coin::mint_for_testing(100_000_000_000, test_scenario::ctx(scenario));

        agentwave_contract::create_agentic_escrow(
            &mut escrow_table,
            main_agent,
            b"Test Project".to_string(),
            b"Testing dispute resolution".to_string(),
            b"Testing".to_string(),
            24,
            100_000_000_000,
            80_000_000_000,
            payment,
            &clock,
            test_scenario::ctx(scenario)
        );
    
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Accept and start job
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::accept_job(
            escrow_id,
            &mut escrow_table,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::start_job(
            escrow_id,
            &mut escrow_table,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(escrow_table);
    };

    // Agent raises dispute
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::dispute_job(
            escrow_id,
            &mut escrow_table,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(escrow_table);
    };

    // Admin refunds main agent
    test_scenario::next_tx(scenario, admin);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::refund_main_agent(
            escrow_id,
            &mut escrow_table,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Verify main agent received refund
    test_scenario::next_tx(scenario, main_agent);
    {
        debug::print(&b"Checking if main agent received refund...".to_string());
        
        if (!test_scenario::has_most_recent_for_address<Coin<SUI>>(main_agent)) {
            debug::print(&b"ERROR: Main agent has NO coin!".to_string());
            abort 999
        };
        
        let coin = test_scenario::take_from_address<Coin<SUI>>(scenario, main_agent);
        let value = coin.value();
        debug::print(&b"Main agent refund received:".to_string());
        debug::print(&value);
    
        test_scenario::return_to_address(main_agent, coin);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_admin_management() {
    let custodian = @custodian_addr;
    let admin1 = @0xA;
    let admin2 = @0xB;
    let admin3 = @0xC;
    let non_custodian = @0xD;

    let mut scenario_val = test_scenario::begin(custodian);
    let scenario = &mut scenario_val;
    
    // Initialize the registry
    test_scenario::next_tx(scenario, custodian);
    {
        agentwave_profile::init_for_test(test_scenario::ctx(scenario));
    };

    // // Test 1: Add first admin
    // test_scenario::next_tx(scenario, custodian);
    // {
    //     let mut registry: AgentRegistry = take_shared(scenario);
    //     let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        
    //     agentwave_profile::add_admin(&mut registry, &admin_cap, admin1, test_scenario::ctx(scenario));
        
    //     assert!(agentwave_profile::check_admin(&registry, admin1), 0);
        
    //     debug::print(&b"Admin1 added successfully".to_string());
        
    //     test_scenario::return_shared(registry);
    //     test_scenario::return_to_sender(scenario, admin_cap);
    // };

    // Test 2: Add second admin
    test_scenario::next_tx(scenario, custodian);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        
        agentwave_profile::add_admin(&mut registry, &admin_cap, admin2, test_scenario::ctx(scenario));
        
        assert!(agentwave_profile::check_admin(&registry, admin1), 1);
        assert!(agentwave_profile::check_admin(&registry, admin2), 2);
        
        debug::print(&b"Admin2 added successfully".to_string());
        
        test_scenario::return_shared(registry);
        test_scenario::return_to_sender(scenario, admin_cap);
    };

    // Test 3: Add third admin
    test_scenario::next_tx(scenario, custodian);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        
        agentwave_profile::add_admin(&mut registry, &admin_cap, admin3, test_scenario::ctx(scenario));
        
        assert!(agentwave_profile::check_admin(&registry, admin1), 3);
        assert!(agentwave_profile::check_admin(&registry, admin2), 4);
        assert!(agentwave_profile::check_admin(&registry, admin3), 5);
        
        debug::print(&b"Admin3 added successfully".to_string());
        
        test_scenario::return_shared(registry);
        test_scenario::return_to_sender(scenario, admin_cap);
    };

    // Test 4: Check non-admin returns false
    test_scenario::next_tx(scenario, custodian);
    {
        let registry: AgentRegistry = take_shared(scenario);
        
        assert!(!agentwave_profile::check_admin(&registry, non_custodian), 6);
        
        debug::print(&b"Non-admin check works correctly".to_string());
        
        test_scenario::return_shared(registry);
    };

    // Test 5: Remove admin2
    test_scenario::next_tx(scenario, custodian);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        
        agentwave_profile::remove_admin(&mut registry, &admin_cap, admin2, test_scenario::ctx(scenario));
        
        assert!(agentwave_profile::check_admin(&registry, admin1), 7);
        assert!(!agentwave_profile::check_admin(&registry, admin2), 8);
        assert!(agentwave_profile::check_admin(&registry, admin3), 9);
        
        debug::print(&b"Admin2 removed successfully".to_string());
        
        test_scenario::return_shared(registry);
        test_scenario::return_to_sender(scenario, admin_cap);
    };

    // Test 6: Remove admin1
    test_scenario::next_tx(scenario, custodian);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        
        agentwave_profile::remove_admin(&mut registry, &admin_cap, admin1, test_scenario::ctx(scenario));
        
        assert!(!agentwave_profile::check_admin(&registry, admin1), 10);
        assert!(!agentwave_profile::check_admin(&registry, admin2), 11);
        assert!(agentwave_profile::check_admin(&registry, admin3), 12);
        
        debug::print(&b"Admin1 removed successfully".to_string());
        
        test_scenario::return_shared(registry);
        test_scenario::return_to_sender(scenario, admin_cap);
    };

    test_scenario::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = agentwave_profile::EAdminExists)]
fun test_add_duplicate_admin() {
    let custodian = @custodian_addr;
    let admin1 = @0xA;

    let mut scenario_val = test_scenario::begin(custodian);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, custodian);
    {
        agentwave_profile::init_for_test(test_scenario::ctx(scenario));
    };

    // Add admin first time
    test_scenario::next_tx(scenario, custodian);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        
        agentwave_profile::add_admin(&mut registry, &admin_cap, admin1, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(registry);
        test_scenario::return_to_sender(scenario, admin_cap);
    };

    // Try to add same admin again - should fail
    test_scenario::next_tx(scenario, custodian);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        
        agentwave_profile::add_admin(&mut registry, &admin_cap, admin1, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(registry);
        test_scenario::return_to_sender(scenario, admin_cap);
    };

    test_scenario::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = agentwave_profile::EAdminCapMismatch)]
fun test_non_custodian_cannot_add_admin() {
    let custodian = @custodian_addr;
    let non_custodian = @0xBAD;
    let admin1 = @0xA;

    let mut scenario_val = test_scenario::begin(custodian);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, custodian);
    {
        agentwave_profile::init_for_test(test_scenario::ctx(scenario));
    };

    // Non-custodian tries to add admin - should fail
    test_scenario::next_tx(scenario, non_custodian);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let admin_cap = test_scenario::take_from_address<AdminCap>(scenario, custodian);
        
        agentwave_profile::add_admin(&mut registry, &admin_cap, admin1, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(registry);
        test_scenario::return_to_address(custodian, admin_cap);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_query_functions() {
    let admin = @0xA;
    let agent1 = @0xB;
    let client = @0xD;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, admin);
    {
        agentwave_contract::init_for_test(test_scenario::ctx(scenario));
    }; 

    test_scenario::next_tx(scenario, admin);
    {
        agentwave_profile::init_for_test(test_scenario::ctx(scenario));
    }; 

    // Register agent
    test_scenario::next_tx(scenario, agent1);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"QueryTest AI".to_string(),
            b"https://avatar.url".to_string(),
            vector<String>[b"testing".to_string()],
            b"Test agent".to_string(),
            b"GPT-4".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Register client
    test_scenario::next_tx(scenario, client);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"Client AI".to_string(),
            b"https://avatar.url".to_string(),
            vector<String>[b"business".to_string()],
            b"Client agent".to_string(),
            b"Custom".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Create multiple escrows
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let payment: Coin<SUI> = coin::mint_for_testing(100_000_000_000, test_scenario::ctx(scenario));

        agentwave_contract::create_agentic_escrow(
            &mut escrow_table,
            agent1,
            b"Project 1".to_string(),
            b"First project".to_string(),
            b"Category A".to_string(),
            24,
            100_000_000_000,
            80_000_000_000,
            payment,
            &clock,
            test_scenario::ctx(scenario)
        );
    
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let payment: Coin<SUI> = coin::mint_for_testing(50_000_000_000, test_scenario::ctx(scenario));

        agentwave_contract::create_agentic_escrow(
            &mut escrow_table,
            agent1,
            b"Project 2".to_string(),
            b"Second project".to_string(),
            b"Category B".to_string(),
            48,
            50_000_000_000,
            40_000_000_000,
            payment,
            &clock,
            test_scenario::ctx(scenario)
        );
    
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Test get_all_escrows
    test_scenario::next_tx(scenario, client);
    {
        let escrow_table: AgenticEscrowTable = take_shared(scenario);

        let all_escrows = agentwave_contract::get_all_escrows(&escrow_table);
        debug::print(&b"All escrows:".to_string());
        debug::print(&all_escrows);
        
        test_scenario::return_shared(escrow_table);
    };

    // Test get_escrows_as_client
    test_scenario::next_tx(scenario, client);
    {
        let escrow_table: AgenticEscrowTable = take_shared(scenario);

        let client_escrows = agentwave_contract::get_escrows_as_client(&escrow_table, client);
        debug::print(&b"Client escrows:".to_string());
        debug::print(&client_escrows);
        
        test_scenario::return_shared(escrow_table);
    };

    // Test get_escrows_as_main_agent
    test_scenario::next_tx(scenario, agent1);
    {
        let escrow_table: AgenticEscrowTable = take_shared(scenario);

        let agent_escrows = agentwave_contract::get_escrows_as_main_agent(&escrow_table, agent1);
        debug::print(&b"Main agent escrows:".to_string());
        debug::print(&agent_escrows);
        
        test_scenario::return_shared(escrow_table);
    };

    // Test get_all_pending_escrows
    test_scenario::next_tx(scenario, client);
    {
        let escrow_table: AgenticEscrowTable = take_shared(scenario);

        let pending_escrows = agentwave_contract::get_all_pending_escrows(&escrow_table);
        debug::print(&b"Pending escrows:".to_string());
        debug::print(&pending_escrows);
        
        test_scenario::return_shared(escrow_table);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_agent_status_toggle() {
    let admin = @0xA;
    let agent1 = @0xB;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, admin);
    {
        agentwave_profile::init_for_test(test_scenario::ctx(scenario));
    };

    // Register agent
    test_scenario::next_tx(scenario, agent1);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::register_agent_profile(
            &mut registry,
            b"StatusTest AI".to_string(),
            b"https://avatar.url".to_string(),
            vector<String>[b"testing".to_string()],
            b"Test status changes".to_string(),
            b"GPT-4".to_string(),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
    };

    // Verify initial active status
    test_scenario::next_tx(scenario, agent1);
    {
        let registry: AgentRegistry = take_shared(scenario);

        let (_, _, _, _, _, _, _, _, _, is_active) = agentwave_profile::get_agent_profile(&registry, agent1);
        assert!(is_active == true, 0);
        debug::print(&b"Initial status: active".to_string());
        
        test_scenario::return_shared(registry);
    };

    // Toggle to inactive
    test_scenario::next_tx(scenario, agent1);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::toggle_agent_status(&mut registry, &clock, test_scenario::ctx(scenario));
        
        clock.destroy_for_testing();
        test_scenario::return_shared(registry);
    };

    // Verify inactive status
    test_scenario::next_tx(scenario, agent1);
    {
        let registry: AgentRegistry = take_shared(scenario);

        let (_, _, _, _, _, _, _, _, _, is_active) = agentwave_profile::get_agent_profile(&registry, agent1);
        assert!(is_active == false, 1);
        debug::print(&b"Status after toggle: inactive".to_string());
        
        test_scenario::return_shared(registry);
    };

    // Toggle back to active
    test_scenario::next_tx(scenario, agent1);
    {
        let mut registry: AgentRegistry = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        agentwave_profile::toggle_agent_status(&mut registry, &clock, test_scenario::ctx(scenario));
        
        clock.destroy_for_testing();
        test_scenario::return_shared(registry);
    };

    // Verify active status again
    test_scenario::next_tx(scenario, agent1);
    {
        let registry: AgentRegistry = take_shared(scenario);

        let (_, _, _, _, _, _, _, _, _, is_active) = agentwave_profile::get_agent_profile(&registry, agent1);
        assert!(is_active == true, 2);
        debug::print(&b"Status after second toggle: active".to_string());
        
        test_scenario::return_shared(registry);
    };

    test_scenario::end(scenario_val);
}

// ===== NEW TESTS FOR FIXED CONTRACT =====

#[test]
fun test_cancel_pending_job() {
    let admin = @0xA;
    let client = @0xD;
    let main_agent = @0xB;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, admin);
    {
        agentwave_contract::init_for_test(test_scenario::ctx(scenario));
    }; 

    // Create escrow
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let payment: Coin<SUI> = coin::mint_for_testing(100_000_000_000, test_scenario::ctx(scenario));

        agentwave_contract::create_agentic_escrow(
            &mut escrow_table,
            main_agent,
            b"Cancellable Project".to_string(),
            b"This will be cancelled".to_string(),
            b"Testing".to_string(),
            24,
            100_000_000_000,
            80_000_000_000,
            payment,
            &clock,
            test_scenario::ctx(scenario)
        );
    
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Client cancels before agent accepts
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::cancel_pending_job(
            escrow_id,
            &mut escrow_table,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        // Verify status is cancelled (8)
        let status = agentwave_contract::get_status(&escrow_table, escrow_id);
        assert!(status == 8, 0); // STATUS_CANCELLED
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Verify client received refund (98% - 2% cancellation fee)
    test_scenario::next_tx(scenario, client);
    {
        debug::print(&b"Checking client refund after cancellation...".to_string());
        
        if (test_scenario::has_most_recent_for_address<Coin<SUI>>(client)) {
            let coin = test_scenario::take_from_address<Coin<SUI>>(scenario, client);
            let value = coin.value();
            debug::print(&b"Client refund received:".to_string());
            debug::print(&value);
            // Should be 98_000_000_000 (98% of 100B)
            assert!(value == 98_000_000_000, 1);
            test_scenario::return_to_address(client, coin);
        };
    };

    test_scenario::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = agentwave_contract::ESubAgentsNotPaid)]
fun test_release_payment_fails_if_sub_agents_not_paid() {
    let admin = @0xA;
    let client = @0xD;
    let main_agent = @0xB;
    let sub_agent = @0xC;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, admin);
    {
        agentwave_contract::init_for_test(test_scenario::ctx(scenario));
    }; 

    // Create escrow
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let payment: Coin<SUI> = coin::mint_for_testing(100_000_000_000, test_scenario::ctx(scenario));

        agentwave_contract::create_agentic_escrow(
            &mut escrow_table,
            main_agent,
            b"Test Project".to_string(),
            b"Testing sub-agent payment requirement".to_string(),
            b"Testing".to_string(),
            24,
            100_000_000_000,
            80_000_000_000,
            payment,
            &clock,
            test_scenario::ctx(scenario)
        );
    
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Accept job
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::accept_job(escrow_id, &mut escrow_table, &clock, test_scenario::ctx(scenario));
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Hire sub-agent
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::hire_sub_agent(
            escrow_id,
            &mut escrow_table,
            sub_agent,
            b"Sub task".to_string(),
            10_000_000_000,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Start and complete job
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::start_job(escrow_id, &mut escrow_table, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(escrow_table);
    };

    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::complete_job(escrow_id, &mut escrow_table, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(escrow_table);
    };

    // Try to release payment WITHOUT paying sub-agent first - should fail
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        // This should abort with ESubAgentsNotPaid
        agentwave_contract::release_payment(
            escrow_id,
            &mut escrow_table,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    test_scenario::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = agentwave_contract::EBudgetExceeded)]
fun test_hire_sub_agent_fails_if_budget_exceeded() {
    let admin = @0xA;
    let client = @0xD;
    let main_agent = @0xB;
    let sub_agent1 = @0xC;
    let sub_agent2 = @0xE;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, admin);
    {
        agentwave_contract::init_for_test(test_scenario::ctx(scenario));
    }; 

    // Create escrow with budget 100, main agent price 80
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let payment: Coin<SUI> = coin::mint_for_testing(100_000_000_000, test_scenario::ctx(scenario));

        agentwave_contract::create_agentic_escrow(
            &mut escrow_table,
            main_agent,
            b"Budget Test".to_string(),
            b"Testing budget validation".to_string(),
            b"Testing".to_string(),
            24,
            100_000_000_000,  // budget = 100 SUI
            80_000_000_000,   // main agent = 80 SUI (leaves 20 SUI for sub-agents)
            payment,
            &clock,
            test_scenario::ctx(scenario)
        );
    
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Accept job
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::accept_job(escrow_id, &mut escrow_table, &clock, test_scenario::ctx(scenario));
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Hire first sub-agent for 15 SUI (total now: 80 + 15 = 95, still within budget)
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::hire_sub_agent(
            escrow_id,
            &mut escrow_table,
            sub_agent1,
            b"First task".to_string(),
            15_000_000_000,  // 15 SUI
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Try to hire second sub-agent for 10 SUI (total would be: 80 + 15 + 10 = 105, exceeds budget)
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        // This should abort with EBudgetExceeded
        agentwave_contract::hire_sub_agent(
            escrow_id,
            &mut escrow_table,
            sub_agent2,
            b"Second task".to_string(),
            10_000_000_000,  // 10 SUI - would exceed budget
            &clock,
            test_scenario::ctx(scenario)
        );
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    test_scenario::end(scenario_val);
}

#[test]
#[expected_failure(abort_code = agentwave_contract::EInsufficientPayment)]
fun test_create_escrow_fails_if_payment_less_than_budget() {
    let admin = @0xA;
    let client = @0xD;
    let main_agent = @0xB;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, admin);
    {
        agentwave_contract::init_for_test(test_scenario::ctx(scenario));
    }; 

    // Try to create escrow with payment < budget
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        // Payment is only 50 SUI but budget is 100 SUI
        let payment: Coin<SUI> = coin::mint_for_testing(50_000_000_000, test_scenario::ctx(scenario));

        // This should abort with EInsufficientPayment
        agentwave_contract::create_agentic_escrow(
            &mut escrow_table,
            main_agent,
            b"Underfunded Project".to_string(),
            b"Payment is less than budget".to_string(),
            b"Testing".to_string(),
            24,
            100_000_000_000,  // budget = 100 SUI
            80_000_000_000,   // main agent = 80 SUI
            payment,          // payment = 50 SUI < budget!
            &clock,
            test_scenario::ctx(scenario)
        );
    
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    test_scenario::end(scenario_val);
}

#[test]
fun test_helper_functions() {
    let admin = @0xA;
    let client = @0xD;
    let main_agent = @0xB;
    let sub_agent = @0xC;

    let mut scenario_val = test_scenario::begin(admin);
    let scenario = &mut scenario_val;
    
    test_scenario::next_tx(scenario, admin);
    {
        agentwave_contract::init_for_test(test_scenario::ctx(scenario));
    }; 

    // Create escrow
    test_scenario::next_tx(scenario, client);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let payment: Coin<SUI> = coin::mint_for_testing(100_000_000_000, test_scenario::ctx(scenario));

        agentwave_contract::create_agentic_escrow(
            &mut escrow_table,
            main_agent,
            b"Helper Test".to_string(),
            b"Testing helper functions".to_string(),
            b"Testing".to_string(),
            24,
            100_000_000_000,
            80_000_000_000,
            payment,
            &clock,
            test_scenario::ctx(scenario)
        );
    
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    // Accept and hire sub-agent
    test_scenario::next_tx(scenario, main_agent);
    {
        let mut escrow_table: AgenticEscrowTable = take_shared(scenario);
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        let escrow_ids_ref = agentwave_contract::get_ids(&escrow_table);
        let escrow_id = *table_vec::borrow(escrow_ids_ref, 0);
        
        agentwave_contract::accept_job(escrow_id, &mut escrow_table, &clock, test_scenario::ctx(scenario));
        
        agentwave_contract::hire_sub_agent(
            escrow_id,
            &mut escrow_table,
            sub_agent,
            b"Sub task".to_string(),
            10_000_000_000,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        // Test get_total_committed
        let total = agentwave_contract::get_total_committed(&escrow_table, escrow_id);
        debug::print(&b"Total committed:".to_string());
        debug::print(&total);
        assert!(total == 90_000_000_000, 0); // 80 + 10 = 90 SUI
        
        // Test all_sub_agents_paid (should be false)
        let all_paid = agentwave_contract::all_sub_agents_paid(&escrow_table, escrow_id);
        assert!(all_paid == false, 1);
        
        clock.destroy_for_testing();
        test_scenario::return_shared(escrow_table);
    };

    test_scenario::end(scenario_val);
}
