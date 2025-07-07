use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use donation::interfaces::idonation_leaderboard::{IDonationLeaderboardDispatcher, IDonationLeaderboardDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

const OWNER: ContractAddress = 0x030f919635ea4063601b47b8b30c3ac43e59f688a5f78d1ac59a4c417ed1a0af.try_into().unwrap();
const ACCEPTED_TOKEN: ContractAddress = 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d.try_into().unwrap(); // STRK
const USER1: ContractAddress = 0x0231b013167a3f3d08f6d8b4c52764e1851b9eefb83fc10a41f71e24de02d8da.try_into().unwrap();
const USER2: ContractAddress = 0x052f15011c668765f1526d8b1deb2ea3c5474aa8c15f1be7d84e279b75afaca4.try_into().unwrap();
const AMOUNT: u256 = 5;
const AMOUNT2: u256 = 3;

fn deploy_contract() -> (IDonationLeaderboardDispatcher, IERC20Dispatcher) {
    let contract = declare("DonationLeaderboard").unwrap();
    let mut constructor_args = array![];
    Serde::serialize(@OWNER, ref constructor_args);
    Serde::serialize(@ACCEPTED_TOKEN, ref constructor_args);
    let (contract_address, _) = contract.contract_class().deploy(@constructor_args).unwrap();
    (IDonationLeaderboardDispatcher { contract_address }, IERC20Dispatcher { contract_address: ACCEPTED_TOKEN })
}

#[test]
#[fork("SEPOLIA_LATEST")]
fn test_donate_and_leaderboard() {
    let (dispatcher, token_dispatcher) = deploy_contract();

    start_cheat_caller_address(token_dispatcher.contract_address, USER1);
    token_dispatcher.approve(dispatcher.contract_address, AMOUNT);
    stop_cheat_caller_address(token_dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, USER1);
    dispatcher.donate(AMOUNT);
    stop_cheat_caller_address(dispatcher.contract_address);

    let donation = dispatcher.get_donation(USER1);
    assert(donation == AMOUNT, 'Incorrect donation amount');

    let leaderboard = dispatcher.get_leaderboard();
    assert(leaderboard.len() == 1, 'Incorrect leaderboard size');

    let (user, amount) = *leaderboard.at(0);
    assert(user == USER1 && amount == AMOUNT, 'Incorrect leaderboard');
}

#[test]
#[fork("SEPOLIA_LATEST")]
fn test_donate_and_badge() {
    let (dispatcher, token_dispatcher) = deploy_contract();

    // User1 donates
    start_cheat_caller_address(token_dispatcher.contract_address, USER1);
    token_dispatcher.approve(dispatcher.contract_address, AMOUNT);
    stop_cheat_caller_address(token_dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, USER1);
    dispatcher.donate(AMOUNT);
    stop_cheat_caller_address(dispatcher.contract_address);

    // User2 donates less
    start_cheat_caller_address(token_dispatcher.contract_address, USER2);
    token_dispatcher.approve(dispatcher.contract_address, AMOUNT2);
    stop_cheat_caller_address(token_dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, USER2);
    dispatcher.donate(AMOUNT2);
    stop_cheat_caller_address(dispatcher.contract_address);

    let badge1 = dispatcher.get_badge(USER1);
    let badge2 = dispatcher.get_badge(USER2);
    assert(badge1 == 'Top Donator', 'User1 should be Top Donator');
    assert(badge2 == 'Donator', 'User2 should be Donator');

    let leaderboard = dispatcher.get_leaderboard();
    assert(leaderboard.len() == 2, 'Incorrect leaderboard size');
    let (user1, amount1) = *leaderboard.at(0);
    let (user2, amount2) = *leaderboard.at(1);
    assert(user1 == USER1 && amount1 == AMOUNT, 'User1 incorrect');
    assert(user2 == USER2 && amount2 == AMOUNT2, 'User2 incorrect');
}

#[test]
#[fork("SEPOLIA_LATEST")]
fn test_withdraw_funds_owner() {
    let (dispatcher, token_dispatcher) = deploy_contract();

    // User1 donates to add funds
    start_cheat_caller_address(token_dispatcher.contract_address, USER1);
    token_dispatcher.approve(dispatcher.contract_address, AMOUNT);
    stop_cheat_caller_address(token_dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, USER1);
    dispatcher.donate(AMOUNT);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Owner withdraws
    start_cheat_caller_address(dispatcher.contract_address, OWNER);
    dispatcher.withdraw_funds(OWNER);
    stop_cheat_caller_address(dispatcher.contract_address);

    let total_donated = dispatcher.get_donation(dispatcher.contract_address);
    assert(total_donated == 0, 'Total donated not reset');
}

#[test]
#[fork("SEPOLIA_LATEST")]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_withdraw_funds_non_owner() {
    let (dispatcher, _) = deploy_contract();

    start_cheat_caller_address(dispatcher.contract_address, USER1);
    dispatcher.withdraw_funds(USER1);
    stop_cheat_caller_address(dispatcher.contract_address);
}