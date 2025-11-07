// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {HYKToken} from "../src/HYKToken.sol";
import {StakingContract} from "../src/StakingContract.sol";

contract DeployStaking is Script {
    uint256 public constant REWARD_POOL_SIZE = 1_000_000 * 10 ** 18; // 1 million HYK tokens

    function run() external returns (HYKToken, StakingContract, address, address) {

        address ethTokenAddress = address(0);
        address ethUsdPriceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        


        address linkTokenAddress = 0x779877a7b0d9E8e02271D54a53531cAa614Ca1AD;
        address linkUsdPriceFeed = 0xca10dD6F7259160107C45aaB7060711A340D805a;
        uint8 linkDecimals = 18;

        vm.startBroadcast();

        HYKToken hykToken = new HYKToken();

        StakingContract stakingContract = new StakingContract(address(hykToken));

        vm.stopBroadcast();

        vm.startBroadcast();

        stakingContract.setEthPriceFeed(ethUsdPriceFeed);
        stakingContract.addAllowedToken(linkTokenAddress, linkUsdPriceFeed, linkDecimals);

        hykToken.mint(address(stakingContract), REWARD_POOL_SIZE);

        vm.stopBroadcast();

        return (hykToken, stakingContract, ethTokenAddress, linkTokenAddress);
    }
}