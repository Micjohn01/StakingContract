// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakeTokens {
    IERC20 public stakingToken;
    address public owner;

    struct UserStake {
        uint amount;
        uint timestamp;
    }

    mapping(address => UserStake) public userStakes;

    uint public constant MONTHLY_REWARD = 5;
    uint public constant SECONDS_IN_A_MONTH = 30 days;
    uint public constant STAKING_DURATION = 180 days;

    event Staked(address _user, uint amount);
    event SuccessfulWithdrawal(address indexed user, uint amount, uint reward);

    constructor(IERC20 _stakingToken, address _owner) {
        stakingToken = _stakingToken;
        owner = _owner;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "only owner");
        _;
    }

    function stake(uint _amount) external {
        require(_amount > 0, "You can't stake 0 tokens");
        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

        userStakes[msg.sender].amount += _amount;
        userStakes[msg.sender].timestamp = block.timestamp;

        emit Staked(msg.sender, _amount);
    }

    function compoundedReward(address _user) public view returns (uint256) {
        UserStake memory userStake = userStakes[_user];
        if (userStake.amount == 0 || block.timestamp < userStake.timestamp + STAKING_DURATION) {
            return 0;
        }

        uint256 stakedMonths = (block.timestamp - userStake.timestamp) / SECONDS_IN_A_MONTH;

        if (stakedMonths > 6) {
            stakedMonths = 6;
        }

        uint256 reward = userStake.amount * ((100 + MONTHLY_REWARD) ** stakedMonths) / (100 ** stakedMonths);

        return reward - userStake.amount;
    }

    function simpleInterestReward(address _user) public view returns (uint256) {
        UserStake memory userStake = userStakes[_user];
        if (userStake.amount == 0 || block.timestamp < userStake.timestamp + STAKING_DURATION) {
            return 0;
        }

        uint256 principal = userStake.amount;
        uint256 rate = MONTHLY_REWARD;
        uint256 time = (block.timestamp - userStake.timestamp) / SECONDS_IN_A_MONTH;

        if (time > 6) {
            time = 6;
        }

        uint256 reward = (principal * rate * time) / 100;

        return reward;
    }

    function withdraw(bool useCompounded) external {
        UserStake memory userStake = userStakes[msg.sender];
        require(userStake.amount > 0, "No staked tokens to withdraw");
        require(block.timestamp >= userStake.timestamp + STAKING_DURATION, "Staking duration not met");

        uint256 reward;

        if (useCompounded) {
            reward = compoundedReward(msg.sender);
        } else {
            reward = simpleInterestReward(msg.sender);
        }

        uint256 totalAmount = userStake.amount + reward;

        userStakes[msg.sender].amount = 0;
        userStakes[msg.sender].timestamp = 0;

        require(stakingToken.transfer(msg.sender, totalAmount), "Token transfer failed");

        emit SuccessfulWithdrawal(msg.sender, userStake.amount, reward);
    }
}
