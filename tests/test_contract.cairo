use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};

use donation::interfaces::idonation_leaderboard::{IDonationLeaderboardDispatcher, IDonationLeaderboardDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// fn deploy_contract(name: ByteArray) -> ContractAddress {
//     let contract = declare(name).unwrap().contract_class();
//     let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
//     contract_address
// }

const OWNER: ContractAddress = 0x007e9244c7986db5e807d8838bcc218cd80ad4a82eb8fd1746e63fe223f67411.try_into().unwrap();
const ACCEPTED_TOKEN: ContractAddress = 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d.try_into().unwrap(); // STRK
const USER1: ContractAddress = 0x000ed03da7bc876b74d81fe91564f8c9935a2ad2e1a842a822b4909203c8e796.try_into().unwrap();
const AMOUNT: u256 = 500;

fn deploy_contract() -> (IDonationLeaderboardDispatcher, IERC20Dispatcher){
    let contract = declare("DonationLeaderboard").unwrap();
    let mut constructor_args = array![];
    Serde::serialize(@OWNER, ref constructor_args);
    Serde::serialize(@ACCEPTED_TOKEN, ref constructor_args);
    let (contract_address, _) = contract.contract_class().deploy(@constructor_args).unwrap();
    (IDonationLeaderboardDispatcher{contract_address}, IERC20Dispatcher{contract_address: ACCEPTED_TOKEN})
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
fn test_donate_and_badge(){
    let (dispatcher, token_dispatcher) = deploy_contract();

    start_cheat_caller_address(token_dispatcher.contract_address, USER1);
    token_dispatcher.approve(dispatcher.contract_address, AMOUNT);
    stop_cheat_caller_address(token_dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, USER1);
    dispatcher.donate(AMOUNT);
    stop_cheat_caller_address(dispatcher.contract_address);

    let badge = dispatcher.get_badge(USER1);
    assert(badge == 'Top Donator', 'Badge not awarded');
}

#[test]
#[fork("SEPOLIA_LATEST")]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_withdraw_funds_non_owner(){
    let (dispatcher, _) = deploy_contract();

    start_cheat_caller_address(dispatcher.contract_address, USER1);
    dispatcher.withdraw_funds(USER1);
    stop_cheat_caller_address(dispatcher.contract_address);
}