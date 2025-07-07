#[starknet::contract]
mod DonationLeaderboard {
    use crate::interfaces::idonation_leaderboard::IDonationLeaderboard;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry};
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: ownableEvent);
    impl OwnableImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        accepted_token: ContractAddress,
        donations: Map<ContractAddress, u256>,
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
        Donated: Donated,
        BadgeAwarded: BadgeAwarded,
        FundsWithdrawn: FundsWithdrawn,
        #[flat]
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

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, accepted_token: ContractAddress) {
        self.ownable.initializer(owner);
        self.accepted_token.write(accepted_token);
        self.leaderboard_size.write(0);
    }

    #[abi(embed_v0)]
    impl DonationLeaderboardImpl of IDonationLeaderboard<ContractState> {
        fn donate(ref self: ContractState, amount: u256) {
            let donator = get_caller_address();
            let token = IERC20Dispatcher { contract_address: self.accepted_token.read() };
            assert(amount > 0, 'Amount must be > 0');
            assert(token.transfer_from(donator, get_contract_address(), amount), 'Transfer failed');

            let current_donation = self.donations.entry(donator).read();
            let new_donation = current_donation + amount;
            self.donations.entry(donator).write(new_donation);
            self.total_donated.write(self.total_donated.read() + amount);

            self.update_leaderboard(donator, new_donation);

            // Clear badges for all leaderboard users except the new top donator
            let size = self.leaderboard_size.read();
            let mut i: u256 = 1;
            let top_donator = self.leaderboard.entry(1).read();
            while i <= size && i <= 5 {
                let user = self.leaderboard.entry(i).read();
                if user.is_non_zero() {
                    if user == top_donator {
                        self.badges.entry(user).write('Top Donator');
                        self.emit(BadgeAwarded { recipient: user, badge: 'Top Donator' });
                    } else {
                        self.badges.entry(user).write('Donator');
                        self.emit(BadgeAwarded { recipient: user, badge: 'Donator' });
                    }
                }
                i += 1;
            }

            self.emit(Donated { donator, amount });
        }

        fn withdraw_funds(ref self: ContractState, recipient: ContractAddress) {
            self.ownable.assert_only_owner();
            let token = IERC20Dispatcher { contract_address: self.accepted_token.read() };
            let amount = self.total_donated.read();
            assert(amount > 0, 'No funds to withdraw');
            assert(token.transfer(recipient, amount), 'Withdrawal failed');
            self.total_donated.write(0);
            self.emit(FundsWithdrawn { recipient, amount });
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
                    result.append((user, self.donations.entry(user).read()));
                }
                i += 1;
            }
            result
        }

        fn get_badge(self: @ContractState, user: ContractAddress) -> felt252 {
            self.badges.entry(user).read()
        }

        fn update_leaderboard(ref self: ContractState, donator: ContractAddress, amount: u256) {
            let mut temp_leaderboard: Array<(ContractAddress, u256)> = array![];
            let size = self.leaderboard_size.read();
            let mut i: u256 = 1;
            while i <= size && i <= 5 {
                let user = self.leaderboard.entry(i).read();
                if user.is_non_zero() && user != donator {
                    temp_leaderboard.append((user, self.donations.entry(user).read()));
                }
                i += 1;
            }
            temp_leaderboard.append((donator, amount));

            let mut sorted = array![];
            while !temp_leaderboard.is_empty() {
                let mut max_idx = 0;
                let mut max_amount: u256 = 0;
                let mut j = 0;
                while j < temp_leaderboard.len() {
                    let (_, amount) = *temp_leaderboard.at(j);
                    if amount >= max_amount {
                        max_amount = amount;
                        max_idx = j;
                    }
                    j += 1;
                }
                sorted.append(*temp_leaderboard.at(max_idx));
                let mut new_temp = array![];
                let mut k = 0;
                while k < temp_leaderboard.len() {
                    if k != max_idx {
                        new_temp.append(*temp_leaderboard.at(k));
                    }
                    k += 1;
                }
                temp_leaderboard = new_temp;
            }

            self.leaderboard_size.write(0);
            let mut rank: u256 = 1;
            while !sorted.is_empty() && rank <= 5 {
                let (user, _) = sorted.pop_front().unwrap();
                self.leaderboard.entry(rank).write(user);
                self.leaderboard_size.write(rank);
                rank += 1;
            }
        }
    }
}