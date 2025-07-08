use starknet::ContractAddress;

#[starknet::interface]
pub trait IDonationLeaderboard<TContractState> {
    fn donate(ref self: TContractState, amount: u256);
    fn withdraw_funds(ref self: TContractState, recipient: ContractAddress);
    fn get_donation(self: @TContractState, donator: ContractAddress) -> u256;
    fn get_leaderboard(self: @TContractState) -> Array<(ContractAddress, u256)>;
    fn get_badge(self: @TContractState, user: ContractAddress) -> felt252;
    fn get_total_donated(self: @TContractState) -> u256;

    fn update_leaderboard(ref self: TContractState, donator: ContractAddress, amount: u256);
}