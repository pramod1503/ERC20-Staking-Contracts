// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract StakingContract is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct AllowedToken {
        address priceFeedAddress;
        uint8 tokenDecimals;
    }

    struct UserInfo {
        uint256 totalValuedStaked;
        uint256 lastStakeTime;
    }

    IERC20 public immutable i_hykToken;

    mapping(address => AllowedToken) public s_allowedTokens;
    mapping(address => mapping(address => uint256)) public s_stakedBalances; // user => token => amount
    mapping(address => UserInfo) public s_userInfo; // user => info

    uint256 public constant REWARD_RATE_PER_SECOND = 3170979198; // ≈10% APY

    event Staked(address indexed user, address indexed token, uint256 amount, uint256 value);
    event Withdrew(address indexed user, address indexed token, uint256 amount, uint256 value);
    event RewardPaid(address indexed user, uint256 reward);
    event AllowTokenAdded(address indexed token, address indexed priceFeed, uint8 decimals);
    event EthPriceFeedSet(address indexed priceFeed, uint8 decimals);

    constructor(address hykTokenAddress) Ownable(msg.sender) {
        i_hykToken = IERC20(hykTokenAddress);
    }

    function addAllowedToken(address tokenAddress, address priceFeedAddress, uint8 tokenDecimals) public onlyOwner {
        require(priceFeedAddress != address(0), "Invalid address");
        s_allowedTokens[tokenAddress] = AllowedToken(priceFeedAddress, tokenDecimals);
        emit AllowTokenAdded(tokenAddress, priceFeedAddress, tokenDecimals);
    }

    function setEthPriceFeed(address priceFeedAddress) external onlyOwner {
        addAllowedToken(address(0), priceFeedAddress, 18);
        emit EthPriceFeedSet(priceFeedAddress, 18);
    }

    function stakeTokens(uint256 amount, address tokenAddress) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(s_allowedTokens[tokenAddress].priceFeedAddress != address(0), "Token not allowed");

        _payReward(msg.sender);

        bool success = IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        _updateStakingBalance(msg.sender, tokenAddress, amount, true);
    }

    function stakeEth() public payable nonReentrant {
        require(msg.value > 0, "Amount must be greater than 0");
        require(s_allowedTokens[address(0)].priceFeedAddress != address(0), "ETH not allowed");

        _payReward(msg.sender);
        _updateStakingBalance(msg.sender, address(0), msg.value, true);
    }

    function withdrawTokens(uint256 amount, address tokenAddress) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(s_stakedBalances[msg.sender][tokenAddress] >= amount, "Insufficient balance");

        _payReward(msg.sender);
        _updateStakingBalance(msg.sender, tokenAddress, amount, false);

        bool success = IERC20(tokenAddress).transfer(msg.sender, amount);
        require(success, "Transfer failed");
    }

    function withdrawEth(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(s_stakedBalances[msg.sender][address(0)] >= amount, "Insufficient balance");

        _payReward(msg.sender);
        _updateStakingBalance(msg.sender, address(0), amount, false);

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function claimReward() external nonReentrant {
        _payReward(msg.sender);
    }

    function calculateReward(address user) public view returns (uint256) {
        UserInfo memory userInfo = s_userInfo[user];
        if (userInfo.totalValuedStaked == 0 || userInfo.lastStakeTime == 0) return 0;

        uint256 timeStaked = block.timestamp - userInfo.lastStakeTime;
        return (userInfo.totalValuedStaked * REWARD_RATE_PER_SECOND * timeStaked) / 1e18;
    }

    function _getTokenValue(address tokenAddress, uint256 amount) internal view returns (uint256) {
        AllowedToken memory allowedToken = s_allowedTokens[tokenAddress];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(allowedToken.priceFeedAddress);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint8 priceFeedDecimals = priceFeed.decimals();

        uint256 priceWith18 = uint256(price) * (10 ** (18 - priceFeedDecimals));
        uint256 amountWith18 = amount * (10 ** (18 - allowedToken.tokenDecimals));

        return (amountWith18 * priceWith18) / 1e18;
    }

    function _updateStakingBalance(
        address user,
        address tokenAddress,
        uint256 amount,
        bool isStaking
    ) internal {
        uint256 value = _getTokenValue(tokenAddress, amount);
        UserInfo storage userInfo = s_userInfo[user];

        if (isStaking) {
            s_stakedBalances[user][tokenAddress] += amount;
            userInfo.totalValuedStaked += value;
            emit Staked(user, tokenAddress, amount, value);
        } else {
            s_stakedBalances[user][tokenAddress] -= amount;
            userInfo.totalValuedStaked -= value;
            emit Withdrew(user, tokenAddress, amount, value);
        }

        userInfo.lastStakeTime = block.timestamp;
    }

    function _payReward(address user) internal {
        uint256 reward = calculateReward(user);
        if (reward > 0) {
            uint256 balance = i_hykToken.balanceOf(address(this));
            require(balance >= reward, "Insufficient HYK balance");
            i_hykToken.safeTransfer(user, reward);
            emit RewardPaid(user, reward);
        }
        s_userInfo[user].lastStakeTime = block.timestamp;
    }

    receive() external payable {
        stakeEth();
    }
}
