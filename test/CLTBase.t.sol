// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { WETH } from "@solmate/tokens/WETH.sol";
import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { Fixtures } from "./utils/Fixtures.sol";
import { Utilities } from "./utils/Utilities.sol";
import { RebaseModuleMock } from "./mocks/RebaseModule.mock.sol";

import { UniswapDeployer } from "./lib/UniswapDeployer.sol";

import { SwapRouter } from "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "forge-std/console.sol";

contract CLTBaseTest is Test, UniswapDeployer {
    IUniswapV3Factory factory;
    IUniswapV3Pool pool;
    SwapRouter router;
    CLTBase base;
    WETH weth;

    Fixtures fixtures;
    Utilities utils;
    RebaseModuleMock rebaseModule;

    event Collect(uint256 tokenId, address recipient, uint256 amount0Collected, uint256 amount1Collected);

    event StrategyCreated(
        bytes32 indexed strategyId, ICLTBase.StrategyKey indexed key, bytes positionActions, bool isCompound
    );

    event Deposit(
        uint256 indexed tokenId, address indexed recipient, uint256 liquidity, uint256 amount0, uint256 amount1
    );

    event Withdraw(
        uint256 indexed tokenId, address indexed recipient, uint256 liquidity, uint256 amount0, uint256 amount1
    );

    function setUp() public {
        utils = new Utilities();
        fixtures = new Fixtures();

        address payable[] memory users = utils.createUsers(5);
        ERC20Mock[] memory tokens = fixtures.deployTokens(2, 1e50);

        // intialize uniswap contracts
        weth = new WETH();
        factory = IUniswapV3Factory(deployUniswapV3Factory());
        pool = IUniswapV3Pool(factory.createPool(address(tokens[0]), address(tokens[1]), 500));
        pool.initialize(TickMath.getSqrtRatioAtTick(0));
        router = new SwapRouter(address(factory), address(weth));

        // initialize base contract with 0.01% protocol fee
        base = new CLTBase("ALP Base", "ALP", address(this), address(0), 10e14, factory);

        rebaseModule = new RebaseModuleMock(msg.sender, address(base));

        // approve tokens
        tokens[0].approve(address(base), type(uint256).max);
        tokens[1].approve(address(base), type(uint256).max);

        tokens[0].approve(address(router), type(uint256).max);
        tokens[1].approve(address(router), type(uint256).max);

        base.addModule(keccak256("REBASE_STRATEGY"), keccak256("TIME_PREFERENCE"), address(rebaseModule), true);
        base.addModule(keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"), address(rebaseModule), true);
        base.addModule(keccak256("REBASE_STRATEGY"), keccak256("REBASE_INACTIVITY"), address(rebaseModule), true);
    }

    /// forge test -vv --match-test testStrategyWithValidInputs
    function testStrategyWithValidInputs() public {
        ICLTBase.StrategyKey memory key = ICLTBase.StrategyKey({ pool: pool, tickLower: -100, tickUpper: 100 });

        ICLTBase.StrategyPayload[] memory exitStrategyActions = new ICLTBase.StrategyPayload[](0);
        ICLTBase.StrategyPayload[] memory rebaseStrategyActions = new ICLTBase.StrategyPayload[](1);
        ICLTBase.StrategyPayload[] memory liquidityDistributionActions = new ICLTBase.StrategyPayload[](0);

        rebaseStrategyActions[0].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseStrategyActions[0].data = abi.encode(4);

        ICLTBase.PositionActions memory actions = ICLTBase.PositionActions({
            mode: 2,
            exitStrategy: exitStrategyActions,
            rebaseStrategy: rebaseStrategyActions,
            liquidityDistribution: liquidityDistributionActions
        });

        // vm.expectEmit(true, true, false, true);
        // emit StrategyCreated(strategyId, key, abi.encode(actions), true);
        base.createStrategy(key, actions, 10e15, true);
        bytes32 strategyId = _getStrategyID(0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76, 1);

        (ICLTBase.StrategyKey memory keyAdded, address owner, bytes memory actionsAdded,, bool isCompound,,,,,,) =
            base.strategies(strategyId);

        assertEq(isCompound, true);
    }

    function test() public { }

    function _getStrategyID(address user, uint256 strategyCount) internal pure returns (bytes32 strategyID) {
        strategyID = keccak256(abi.encode(user, strategyCount));
    }
}
