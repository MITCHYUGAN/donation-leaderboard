#[starknet::contract]
mod DonationLeaderboard {
    
    use crate::interfaces::idonation_leaderboard::IDonationLeaderboard;

    use starknet::{ContractAddress, get_caller_address, get_contract_address,};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry};
    use core::num::traits::Zero;

    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: ownableEvent );
    impl OwnableImpl = OwnableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        accepted_token: ContractAddress, // ERC20 token (e.g., STRK)
        donations: Map<ContractAddress, u256>, // User -> Donated_amount
        total_donated: u256,
        leaderboard: Map<u256, ContractAddress>,
        badges: Map<ContractAddress, felt252>,
        leaderboard_size: u256,

        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        Donated: Donated,
        BadgeAwarded: BadgeAwarded,
        FundsWithdrawn: FundsWithdrawn,

        ownableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct Donated {
        donator: ContractAddress, 
        amount: u256,
    }
    
    #[derive(Drop, starknet::Event)]
    struct BadgeAwarded {
        recipient: ContractAddress,
        badge: felt252,
    }
    
    #[derive(Drop, starknet::Event)]
    struct FundsWithdrawn {
        recipient: ContractAddress,
        amount: u256,
    }


    #[abi(embed_v0)]
    impl DonationLeaderboardImpl of IDonationLeaderboard<ContractState> {
        fn donate(ref self: ContractState, amount: u256){
            let donator = get_caller_address();
            let token = IERC20Dispatcher{contract_address: self.accepted_token.read()};
            assert(token.transfer_from(donator, get_contract_address(), amount), 'Transfer failed');

            // Make sure donations add to previous ones (if any) and not override
            let current_donation = self.donations.entry(donator).read();
            let new_donation = current_donation + amount;

            self.donations.entry(donator).write(new_donation);
            self.total_donated.write(self.total_donated.read() + amount);

            self.update_leaderboard(donator, new_donation);

            if self.leaderboard.entry(1).read() == donator {
                self.badges.entry(donator).write('Top Donator');
                self.emit(BadgeAwarded{recipient: donator, badge: 'Top Donator'})
            }

            self.emit(Donated{donator, amount})
        }

        fn withdraw_funds(ref self: ContractState, recipient: ContractAddress){
            self.ownable.assert_only_owner();

            let token = IERC20Dispatcher{contract_address: self.accepted_token.read()};
            let amount = self.total_donated.read();

            assert(amount > 0, 'No funds to withdraw');
            assert(token.transfer(recipient, amount), 'Withdrawal failed');

            self.total_donated.write(0);
            self.emit(FundsWithdrawn{recipient, amount})
        }

        fn get_donation(self: @ContractState, donator: ContractAddress) -> u256 {
            self.donations.entry(donator).read()
        }


        fn get_leaderboard(self: @ContractState) -> Array<(ContractAddress, u256)> {
            let mut result = array![];
            let size = self.leaderboard_size.read();
            let mut i: u256 = 1;
            while i <= size && i <= 5 {
                let user = self.leaderboard.entry(i).read();
                if user.is_non_zero() {
                    result.append((user, self.donations.entry(user).read()))
                }
                i += 1;
            };
            result
        }

        fn get_badge(self: @ContractState, user: ContractAddress) -> felt252 {
            self.badges.entry(user).read()
        }

        fn update_leaderboard(ref self: ContractState, donator: ContractAddress, amount: u256){

        }
    }
}
