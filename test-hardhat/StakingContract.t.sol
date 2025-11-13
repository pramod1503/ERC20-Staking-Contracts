// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StakingContract} from "../src/StakingContract.sol";
import {HYKToken} from "../src/HYKToken.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

contract StakingContractTest is Test {
    /* ========== STATE VARIABLES ========== */

    StakingContract public stakingContract;
    HYKToken public hykToken;
    MockERC20 public linkToken;
    MockERC20 public usdtToken;
    MockV3Aggregator public linkPriceFeed;
    MockV3Aggregator public usdtPriceFeed;
    MockV3Aggregator public ethPriceFeed;

    // Test Users
    address public constant USER_1 = address(0x1);
    uint256 public constant STARTING_BALANCE = 1000 * 1e18;

    int256 public constant LINK_PRICE = 20 * 1e8;
    uint8 public constant LINK_DECIMALS = 8;

    int256 public constant USDT_PRICE = 1 * 1e6;
    uint8 public constant USDT_DECIMALS = 6;

    int256 public constant ETH_PRICE = 3000 * 1e8;
    uint8 public constant ETH_DECIMALS = 8;

    /* ========== SETUP ========== */

    function setUp() public {
        // --- 1. DEPLOY ALL MOCKS AND TOKENS ---
        hykToken = new HYKToken();
        linkToken = new MockERC20("Mock LINK", "mLINK");
        usdtToken = new MockERC20("Mock USDT", "mUSDT");

        linkPriceFeed = new MockV3Aggregator(LINK_PRICE, LINK_DECIMALS);
        usdtPriceFeed = new MockV3Aggregator(USDT_PRICE, USDT_DECIMALS);
        ethPriceFeed = new MockV3Aggregator(ETH_PRICE, ETH_DECIMALS);

        // --- 2. DEPLOY THE MAIN CONTRACT ---

        stakingContract = new StakingContract(address(hykToken));

        hykToken.mint(address(stakingContract), 1_000_000 * 1e18);

        stakingContract.addAllowedToken(address(linkToken), address(linkPriceFeed), 18);
        stakingContract.addAllowedToken(address(usdtToken), address(usdtPriceFeed), 18);
        stakingContract.setEthPriceFeed(address(ethPriceFeed));

        // --- 4. GIVE OUR TEST USER SOME ASSETS ---
        vm.deal(USER_1, STARTING_BALANCE);
        linkToken.mint(USER_1, STARTING_BALANCE);
        usdtToken.mint(USER_1, STARTING_BALANCE);
    }

    /* ========== TESTS (We will build these next) ========== */

    function test_ExampleTest() public view {
        assertEq(linkToken.balanceOf(USER_1), STARTING_BALANCE);
    }

    function test_StakeTokens_FailsIfTokenNotAllowed() public {}

    function test_StakeTokens_PerformsApproveAndTransferFrom() public {}

    function test_StakeEth_UpdatesValueCorrectly() public {}
}
