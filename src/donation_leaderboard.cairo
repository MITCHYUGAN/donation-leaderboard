#[starknet::contract]
mod DonationLeaderboard {
    use crate::interfaces::idonation_leaderboard::IDonationLeaderboard;

    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry};

    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    // component!(path: )

    #[storage]
    struct Storage {
        accepted_token: ContractAddress, // ERC20 token (e.g., STRK)
        donations: Map<ContractAddress, u256>, // User -> Donated_amount
        total_donated: u256,
        leaderboard: Map<u256, ContractAddress>,
        badges: Map<ContractAddress, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        Donated: Donated,
        BadgeAwarded: BadgeAwarded,
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
            
        }

        fn get_donation(self: @ContractState, donator: ContractAddress) -> u256 {
            5
        }


        fn get_leaderboard(self: @ContractState) -> Array<(ContractAddress, u256)> {

        }

        fn get_badge(self: @ContractState, user: ContractAddress) -> felt252 {
            5
        }

        fn update_leaderboard(ref self: ContractState, donator: ContractAddress, amount: u256){

        }
    }
}
