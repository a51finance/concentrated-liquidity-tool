// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { RebaseFixtures } from "./utils/RebaseFixtures.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { PoolActions } from "../src/libraries/PoolActions.sol";
import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { PositionKey } from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { LiquidityAmounts } from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";

/**
 * FUNCTIONS TO TEST
 *  getPreferenceTicks()
 *  checkInputData()
 *  executeStrategy()
 *     _getSwapAmount()
 *      getZeroForOne()
 *      getTicksForModeWithActions()
 *      getTicksForModeActive()
 *      getStrategyData()
 *      shouldAddToQueue()
 *      _checkActiveRebalancingStrategies()
 *  updateSlippagePercentage()
 */
contract ActiveRebalancingTest is Test, RebaseFixtures {
    address payable[] users;
    address owner;

    function setUp() public {
        users = createUsers(5);
        owner = address(this);
        initBase(owner, 10_000_000e18, 10_000_000e18);
    }

    function getPositionLiquidity(ICLTBase.StrategyKey memory key)
        public
        view
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        bytes32 positionKey = PositionKey.compute(address(base), key.tickLower, key.tickUpper);

        (liquidity, feeGrowthInside0LastX128, feeGrowthInside1LastX128, tokensOwed0, tokensOwed1) =
            key.pool.positions(positionKey);
    }

    function testCreateStrategyAR() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(1000, 1000, tick, strategyKey.tickLower, strategyKey.tickUpper);

        positionActions.mode = 3;
        positionActions.rebaseStrategy = rebaseActions;

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 1500, owner, 1, 3, false, 1000e18, 1000e18);

        (ICLTBase.StrategyKey memory key,, bytes memory actionsData,,,,,, ICLTBase.Account memory account) =
            base.strategies(strategyID);
        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        (int24 lowerPreferenceTick, int24 upperPreferenceTick,,) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), rebaseActions[0].data);

        (, tick,,,,,) = pool.slot0();
        assertEq(address(key.pool), address(key.pool));

        console.log("Remaining Balance0", account.balance0 / 1e18);
        console.log("Remaining Balance0", account.balance1 / 1e18);
        console.log("Reserves0", reserve0 / 1e18);
        console.log("Reserves1", reserve1 / 1e18);

        console.log("==========BEFORE SWAP==============");

        console.logInt(key.tickLower);
        console.logInt(lowerPreferenceTick);
        console.logInt(tick);
        console.logInt(upperPreferenceTick);
        console.logInt(key.tickUpper);

        // do a small swap
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 150_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 150_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (key,, actionsData,,,,,,) = base.strategies(strategyID);

        (lowerPreferenceTick, upperPreferenceTick,,) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), rebaseActions[0].data);

        (, tick,,,,,) = pool.slot0();

        console.log("==========AFTER SWAP==============");

        console.logInt(key.tickLower);
        console.logInt(lowerPreferenceTick);
        console.logInt(tick);
        console.logInt(upperPreferenceTick);
        console.logInt(key.tickUpper);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;

        rebaseModule.executeStrategies(strategyIDs);

        (lowerPreferenceTick, upperPreferenceTick,,) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), rebaseActions[0].data);

        (key,,,,,,,, account) = base.strategies(strategyID);

        console.log("========================");

        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);
        console.log("Remaining Balance0", account.balance0 / 1e18);
        console.log("Remaining Balance0", account.balance1 / 1e18);
        console.log("Reserves0", reserve0 / 1e18);
        console.log("Reserves1", reserve1 / 1e18);

        console.log("=========== TICKS DATA =============");

        (lowerPreferenceTick, upperPreferenceTick,,) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), rebaseActions[0].data);
        (key,,,,,,,, account) = base.strategies(strategyID);
        (, tick,,,,,) = pool.slot0();

        console.logInt(key.tickLower);
        console.logInt(lowerPreferenceTick);
        console.logInt(tick);
        console.logInt(upperPreferenceTick);
        console.logInt(key.tickUpper);
    }

    function testCreateStrategyARPartial() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        (, int24 tick,,,,,) = pool.slot0();

        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        positionActions.mode = 3;
        positionActions.rebaseStrategy = rebaseActions;

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 3, false, 1000e18, 1000e18);

        (ICLTBase.StrategyKey memory key,, bytes memory actionsData,,,,,, ICLTBase.Account memory account) =
            base.strategies(strategyID);

        (int24 lowerPreferenceTick, int24 upperPreferenceTick,,) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), rebaseActions[0].data);

        (, tick,,,,,) = pool.slot0();

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        console.log("Remaining Balance0", account.balance0 / 1e18);
        console.log("Remaining Balance0", account.balance1 / 1e18);
        console.log("Reserves0", reserve0 / 1e18);
        console.log("Reserves1", reserve1 / 1e18);

        assertEq(address(key.pool), address(key.pool));
        _hevm.warp(block.timestamp + 3600);

        console.log("==========BEFORE SWAP==============");

        console.logInt(key.tickLower);
        console.logInt(lowerPreferenceTick);
        console.logInt(tick);
        console.logInt(upperPreferenceTick);
        console.logInt(key.tickUpper);
        console.log("==========AFTER SWAP==============");

        // do a small swap
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        // executeSwap(token0, token1, pool.fee(), owner, 150_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 17_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);
        (, tick,,,,,) = pool.slot0();

        console.logInt(key.tickLower);
        console.logInt(lowerPreferenceTick);
        console.logInt(tick);
        console.logInt(upperPreferenceTick);
        console.logInt(key.tickUpper);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);
        (key,, actionsData,,,,,,) = base.strategies(strategyID);

        (lowerPreferenceTick, upperPreferenceTick,,) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), rebaseActions[0].data);
        console.log("========================");

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);
        console.log("Remaining Balance0", account.balance0 / 1e18);
        console.log("Remaining Balance0", account.balance1 / 1e18);
        console.log("Reserves0", reserve0 / 1e18);
        console.log("Reserves1", reserve1 / 1e18);
    }

    function test_ActiveRebalance_create_normal_strategy_compound() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](3);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(400, 350, tick, strategyKey.tickLower, strategyKey.tickUpper);

        rebaseActions[2].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[2].data = abi.encode(10);
        positionActions.mode = 2;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, true, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);
        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID);

        assertEq(address(strategyKey.pool), address(key.pool));
    }

    // checkInputData
    function test_ActiveRebalance_cannot_create_stratgy_with_invalid_input_data() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModule.ACTIVE_REBALANCE();
        strategyDetail.data = abi.encode((0));

        vm.expectRevert(IRebaseStrategy.RebaseStrategyDataCannotBeZero.selector);
        rebaseModule.checkInputData(strategyDetail);

        strategyDetail.data = abi.encode(int24(-45), int24(-334));

        vm.expectRevert(IRebaseStrategy.InvalidRebalanceThresholdDifference.selector);
        rebaseModule.checkInputData(strategyDetail);

        strategyDetail.data = abi.encode(int24(450), int24(-334));

        vm.expectRevert(IRebaseStrategy.InvalidRebalanceThresholdDifference.selector);
        rebaseModule.checkInputData(strategyDetail);
    }

    function test_ActiveRebalance_cannot_create_stratgy_with_valid_input_data() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModule.ACTIVE_REBALANCE();
        strategyDetail.data = abi.encode(int24(450), int24(334));

        assertTrue(rebaseModule.checkInputData(strategyDetail));
    }

    // getPreferenceTicks()
    function test_ActiveRebalance_get_preference_ticks() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](3);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(100, 100);

        initStrategy(1500);

        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(600, 350, tick, strategyKey.tickLower, strategyKey.tickUpper);

        rebaseActions[2].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[2].data = abi.encode(1);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, true, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);
        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID);

        // For Active Rebalancing
        (int24 lowerPreferenceTick, int24 upperPreferenceTick,,) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data);

        assertEq(lowerPreferenceTick, key.tickLower + 600);
        assertEq(upperPreferenceTick, key.tickUpper - 350);

        // For Price Preference
        (lowerPreferenceTick, upperPreferenceTick,,) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseActions[1].actionName, rebaseActions[1].data);

        assertEq(lowerPreferenceTick, key.tickLower - 100);
        assertEq(upperPreferenceTick, key.tickUpper + 100);
    }

    // executeStrategy()
    function test_executeStrategy_AR_with_valid_data() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);
        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        positionActions.mode = 3;
        positionActions.rebaseStrategy = rebaseActions;

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 3, false, 1000e18, 1000e18);

        (ICLTBase.StrategyKey memory key,, bytes memory actionsData,,,,,,) = base.strategies(strategyID);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 17_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        (ICLTBase.StrategyKey memory keyAfter,, bytes memory actionsDataAfter,,,,,,) = base.strategies(strategyID);

        assertEq(key.tickLower != keyAfter.tickLower, true);
        assertEq(key.tickUpper != keyAfter.tickUpper, true);

        (int24 tdlb, int24 tdub) = abi.decode(actionsData, (int24, int24));
        (int24 tdla, int24 tdua) = abi.decode(actionsDataAfter, (int24, int24));

        assertEq(tdlb == tdla, true);
        assertEq(tdub == tdua, true);
    }

    function test_Execute_Strategy_with_mode_1_only() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 1, false, 1000e18, 1000e18);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 17_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // For Bear
        assertTrue(t < tlp);
        assertTrue(tl < tlp);
        assertTrue(t > tl);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // // For Bear
        // assertTrue(t > tlp);
        // assertTrue(t < tup);
        // assertTrue(tup < tu);
        // assertTrue(tl < tlp);
        // assertTrue(t > tl);
    }

    function test_Execute_Strategy_with_mode_1_compounded() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID = createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 1, true, 1000e18, 1000e18);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 17_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        int256 ldb = tl - tlp;
        int256 udb = tu - tup;

        // For Bear
        assertTrue(t < tlp);
        assertTrue(tl < tlp);
        assertTrue(t > tl);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        console.log("Balance0 Before", account.balance0);
        console.log("Balance1 Before", account.balance1);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // For Bear
        assertTrue(t > tlp);
        assertTrue(t < tup);
        assertTrue(tup < tu);
        assertTrue(tl < tlp);
        assertTrue(t > tl);

        (,,,,,,,, account) = base.strategies(strategyID);

        console.log("Balance0 After", account.balance0);
        console.log("Balance1 After", account.balance1);
    }

    function test_Execute_Strategy_with_mode_1_against() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 1, false, 1000e18, 1000e18);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(t > tup);
        assertTrue(tup < tu);
        assertTrue(t < tu);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        int256 ptl = tl;
        int256 ptu = tu;

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t > tup);
        assertTrue(tup < tu);
        assertTrue(t < tu);

        // checking differences
        assertTrue(ptl == tl);
        assertTrue(ptu == tu);
    }

    function test_Execute_Strategy_with_mode_2() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 2, false, 1000e18, 1000e18);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // For Bull
        assertTrue(t > tup);
        assertTrue(tu > tup);
        assertTrue(t < tu);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // For Bull
        assertTrue(t > tlp);
        assertTrue(t < tup);
        assertTrue(tup < tu);
        assertTrue(tl < tlp);
        assertTrue(t > tl);
        assertTrue(t < tu);
    }

    function test_Execute_Strategy_with_mode_2_compounded() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID = createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 2, true, 1000e18, 1000e18);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // For Bull
        assertTrue(t > tup);
        assertTrue(tu > tup);
        assertTrue(t < tu);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        console.log("Balance0 Before", account.balance0);
        console.log("Balance1 Before", account.balance1);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // For Bull
        assertTrue(t > tlp);
        assertTrue(t < tup);
        assertTrue(tup < tu);
        assertTrue(tl < tlp);
        assertTrue(t > tl);
        assertTrue(t < tu);

        (,,,,,,,, account) = base.strategies(strategyID);

        console.log("Balance0 After", account.balance0);
        console.log("Balance1 After", account.balance1);
    }

    function test_Execute_Strategy_with_mode_2_against() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 2, false, 1000e18, 1000e18);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 17_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t < tlp);
        assertTrue(tlp > tl);
        assertTrue(t > tl);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        int256 ptl = tl;
        int256 ptu = tu;

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t < tlp);
        assertTrue(tlp > tl);
        assertTrue(t > tl);

        // checking differences
        assertTrue(ptl == tl);
        assertTrue(ptu == tu);
    }

    function test_Execute_Strategy_with_mode_3() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 3, false, 1000e18, 1000e18);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 17_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // For Bear
        assertTrue(t < tlp);
        assertTrue(tl < tlp);
        assertTrue(t > tl);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // For Bear
        assertTrue(t > tlp);
        assertTrue(t < tup);
        assertTrue(tup < tu);
        assertTrue(tl < tlp);
        assertTrue(t > tl);
    }

    function test_Execute_Strategy_with_mode_3_1() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 3, false, 1000e18, 1000e18);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // For Bull
        assertTrue(t > tup);
        assertTrue(tu > tup);
        assertTrue(t < tu);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // For Bull
        assertTrue(t > tlp);
        assertTrue(t < tup);
        assertTrue(tup < tu);
        assertTrue(tl < tlp);
        assertTrue(t > tl);
        assertTrue(t < tu);
    }

    // with PP first

    function test_Execute_Strategy_with_PP_AR_mode_1() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        // TickCalculatingVars memory tickCalculatingVars;
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[1].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[1].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 1, false, 1000e18, 1000e18);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 17_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // tick has crossed both inner and outer threshold
        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t < tl);
        assertTrue(t < tlp);

        (,,, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(t < tl);
        assertTrue(t < tlp);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        // since Price Preference is provided first in the array therefore contract prioritzes it.
        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(tl > t);
        assertTrue(tu > t);
        assertTrue(tu > tl);

        // taking the price more backwards
        executeSwap(token0, token1, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        rebaseModule.executeStrategies(strategyIDs);

        // since Price Preference is provided first in the array therefore contract prioritzes it.
        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(tl > t);
        assertTrue(tu > t);
        assertTrue(tu > tl);
    }

    function test_Execute_Strategy_with_PP_AR_mode_2() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        // TickCalculatingVars memory tickCalculatingVars;
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[1].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[1].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 2, false, 1000e18, 1000e18);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // tick has crossed both inner and outer threshold
        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t > tu);
        assertTrue(t > tup);

        (,,, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(t > tu);
        assertTrue(t > tup);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        // since Price Preference is provided first in the array therefore contract prioritzes it.
        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(tl < t);
        assertTrue(tu < t);
        assertTrue(tu > tl);

        // taking the price more forward
        executeSwap(token1, token0, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        rebaseModule.executeStrategies(strategyIDs);

        // since Price Preference is provided first in the array therefore contract prioritzes it.
        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(tl < t);
        assertTrue(tu < t);
        assertTrue(tu > tl);
    }

    // with AR first
    function test_Execute_Strategy_with_AR_PP_mode_1() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        // TickCalculatingVars memory tickCalculatingVars;
        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 1, false, 1000e18, 1000e18);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 17_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // tick has crossed both inner and outer threshold
        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t < tl);
        assertTrue(t < tlp);

        (,,, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(t < tl);
        assertTrue(t < tlp);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        // since Active Rebalance is provided first in the array therefore contract prioritzes it.
        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(tl < t);
        assertTrue(tu > t);
        assertTrue(tu > tl);
        assertTrue(tu > tup);
        assertTrue(tl < tlp);

        // taking the price more forward
        executeSwap(token0, token1, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t < tl);
        assertTrue(t < tlp);

        rebaseModule.executeStrategies(strategyIDs);

        // since Active Rebalance is provided first in the array therefore contract prioritzes it.
        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(tl < t);
        assertTrue(tu > t);
        assertTrue(tu > tl);
        assertTrue(tu > tup);
        assertTrue(tl < tlp);
    }

    function test_Execute_Strategy_with_AR_PP_mode_2() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        // TickCalculatingVars memory tickCalculatingVars;
        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 2, false, 1000e18, 1000e18);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // tick has crossed both inner and outer threshold
        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t > tu);
        assertTrue(t > tup);

        (,,, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(t > tu);
        assertTrue(t > tup);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        // since Active Rebalance is provided first in the array therefore contract prioritzes it.
        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(tl < t);
        assertTrue(tu > t);
        assertTrue(tu > tl);
        assertTrue(tu > tup);
        assertTrue(tl < tlp);

        // taking the price more forward
        executeSwap(token1, token0, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t > tu);
        assertTrue(t > tup);

        rebaseModule.executeStrategies(strategyIDs);

        // since Active Rebalance is provided first in the array therefore contract prioritzes it.
        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(tl < t);
        assertTrue(tu > t);
        assertTrue(tu > tl);
        assertTrue(tu > tup);
        assertTrue(tl < tlp);
    }

    function test_Execute_Strategy_with_hodl_complete_ofr() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 2, false, 1000e18, 1000e18);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // tick has crossed both inner and outer threshold
        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t > tu);
        assertTrue(t > tup);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = tl;
        executeParams.tickUpper = tu;
        executeParams.shouldMint = false;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        // since Active Rebalance is provided first in the array therefore contract prioritzes it.
        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(t > tu);
        assertTrue(t > tup);
    }

    function test_Execute_Strategy_with_hodl_partial_ofr() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 2, false, 1000e18, 1000e18);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        // executeSwap(token1, token0, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // tick has crossed both inner and outer threshold
        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t < tu);
        assertTrue(t > tup);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = strategyID;
        executeParams.tickLower = tl;
        executeParams.tickUpper = tu;
        executeParams.shouldMint = false;
        executeParams.zeroForOne = false;
        executeParams.swapAmount = 0;

        rebaseModule.executeStrategy(executeParams);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        // since Active Rebalance is provided first in the array therefore contract prioritzes it.
        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(tl < t);
        assertTrue(tu > t);
        assertTrue(tu > tl);
        assertTrue(tu > tup);
        assertTrue(tl < tlp);
    }

    function test_Execute_Strategy_with_tax() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        initStrategy(150);
        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        positionActions.mode = 2;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        base.createStrategy(strategyKey, positionActions, 1e15, 15e15, true, false);

        bytes32 strategyID = getStrategyID(address(this), 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 1000e18;
        depositParams.amount1Desired = 1000e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = address(this);
        base.deposit(depositParams);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // tick has crossed both inner and outer threshold
        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, true);

        assertTrue(t > tu);
        assertTrue(t > tup);

        (,,, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        // assertTrue(t > tu);
        // assertTrue(t > tup);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        console.log("Balance0 Before", account.balance0);
        console.log("Balance1 Before", account.balance1);
    }

    function test_Execute_Strategy_shouldnt_rebalance_after_inactivity() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](3);
        // TickCalculatingVars memory tickCalculatingVars;
        rebaseActions[2].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[2].data = abi.encode(1);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 3, false, 1000e18, 1000e18);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // tick has crossed both inner and outer threshold
        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t > tu);
        assertTrue(t > tup);

        (,,, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(t > tu);
        assertTrue(t > tup);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        // since Active Rebalance is provided first in the array therefore contract prioritzes it.
        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        assertTrue(tl < t);
        assertTrue(tu > t);
        assertTrue(tu > tl);
        assertTrue(tu > tup);
        assertTrue(tl < tlp);

        // taking the price more forward
        executeSwap(token1, token0, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t > tu);
        assertTrue(t > tup);

        rebaseModule.executeStrategies(strategyIDs);
    }

    function test_Execute_Strategy_remaining_balance_check() public {
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);

        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        initStrategy(150);
        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        base.createStrategy(strategyKey, positionActions, 0, 0, true, false);

        bytes32 strategyID = getStrategyID(address(this), 1);
        (uint256 deposit0, uint256 deposit1) = getAmounts(strategyKey.tickLower, strategyKey.tickUpper, 100e18);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = deposit0;
        depositParams.amount1Desired = deposit1;
        depositParams.amount0Min = deposit0 - 2;
        depositParams.amount1Min = deposit1 - 2;
        depositParams.recipient = address(this);
        base.deposit(depositParams);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        console.log("Remaining Balance0", account.balance0 / 1e18);
        console.log("Remaining Balance0", account.balance1 / 1e18);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 65_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // assertTrue(t < tu);
        // assertTrue(t > tup);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        (,,,,,,,, account) = base.strategies(strategyID);

        console.log("Balance0 After", account.balance0 / 1e18);
        console.log("Balance1 After", account.balance1 / 1e18);
    }

    function test_Execute_Strategy_with_tax_2() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        initStrategy(150);
        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        positionActions.mode = 2;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        feeHandler.setPublicFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 10_000,
                strategyCreationFee: 0,
                protcolFeeOnManagement: 0,
                protcolFeeOnPerformance: 0
            })
        );

        base.createStrategy(strategyKey, positionActions, 1e15, 15e15, true, false);

        bytes32 strategyID = getStrategyID(address(this), 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 1000e18;
        depositParams.amount1Desired = 1000e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = address(this);
        base.deposit(depositParams);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // tick has crossed both inner and outer threshold
        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        assertTrue(t > tu);
        assertTrue(t > tup);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        console.log("Balance0 Before", account.balance0);
        console.log("Balance1 Before", account.balance1);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);
    }

    function test_Execute_Strategy_updating_slippage() public {
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);

        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        initStrategy(150);
        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        base.createStrategy(strategyKey, positionActions, 0, 0, true, false);

        bytes32 strategyID = getStrategyID(address(this), 1);
        (uint256 deposit0, uint256 deposit1) = getAmounts(strategyKey.tickLower, strategyKey.tickUpper, 100e18);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = deposit0;
        depositParams.amount1Desired = deposit1;
        depositParams.amount0Min = deposit0 - 2;
        depositParams.amount1Min = deposit1 - 2;
        depositParams.recipient = address(this);
        base.deposit(depositParams);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        console.log("Remaining Balance0", account.balance0 / 1e18);
        console.log("Remaining Balance0", account.balance1 / 1e18);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 17_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 65_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        _hevm.expectRevert(abi.encodeWithSignature("SlippageThresholdExceeded()"));
        rebaseModule.updateSlippagePercentage(1e8);

        rebaseModule.updateSlippagePercentage(1e7);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        (,,,,,,,, account) = base.strategies(strategyID);

        console.log("Balance0 After", account.balance0 / 1e18);
        console.log("Balance1 After", account.balance1 / 1e18);
    }

    function test_Execute_Strategy_providing_OFR_liqudity() public {
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);

        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;
        initStrategy(150);
        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        strategyKey.tickLower = 10;
        base.createStrategy(strategyKey, positionActions, 0, 0, true, false);

        bytes32 strategyID = getStrategyID(address(this), 1);
        (uint256 deposit0, uint256 deposit1) = getAmounts(strategyKey.tickLower, strategyKey.tickUpper, 100e18);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = deposit0;
        depositParams.amount1Desired = deposit1;
        depositParams.amount0Min = deposit0 - 2;
        depositParams.amount1Min = deposit1 - 2;
        depositParams.recipient = address(this);
        base.deposit(depositParams);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        console.log("Remaining Balance0", account.balance0 / 1e18);
        console.log("Remaining Balance0", account.balance1 / 1e18);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        (,,,,,,,, account) = base.strategies(strategyID);

        console.log("Balance0 After", account.balance0 / 1e18);
        console.log("Balance1 After", account.balance1 / 1e18);
    }

    function testGetPreferenceTicksActive1() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;

        (, int24 tick,,,,,) = pool.slot0();

        int24 tickLower = floorTicks(tick - 150, pool.tickSpacing());
        int24 tickUpper = floorTicks(tick + 30, pool.tickSpacing());

        strategyKey.pool = pool;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;

        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(140, 20, tick, tickLower, tickUpper);

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        base.createStrategy(strategyKey, positionActions, 0, 0, false, false);

        bytes32 strategyID = getStrategyID(address(this), 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 100e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = address(this);
        base.deposit(depositParams);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 10_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), abi.encode(140, 20, tick, tickLower, tickUpper),
        // true);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);
        console.log("======================");

        getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), abi.encode(140, 20, tick, tickLower, tickUpper), true);

        // (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) = getAllTicks(
        //     strategyID, rebaseModule.ACTIVE_REBALANCE(), abi.encode(140, 20, tick, tickLower, tickUpper), true
        // );

        // assertTrue(tl < tlp);
        // assertTrue(tlp < t);
        // assertTrue(tu > tup);
        // assertTrue(tup > t);
    }

    function testGetPreferenceTicksActive2() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 220e18, 0, 0);

        (, int24 tick,,,,,) = pool.slot0();

        int24 tickLower = floorTicks(tick - 30, pool.tickSpacing());
        int24 tickUpper = floorTicks(tick + 300, pool.tickSpacing());

        strategyKey.pool = pool;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;
        bytes memory data = abi.encode(27, 20, tick, tickLower, tickUpper);
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = data;

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        base.createStrategy(strategyKey, positionActions, 0, 0, false, false);

        bytes32 strategyID = getStrategyID(address(this), 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 100e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = address(this);
        base.deposit(depositParams);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 10_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 175_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);
        console.log("===========AFTER SWAPPING===========");
        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);
        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        console.log("===========AFTER REBALANCE===========");

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);

        assertTrue(tl < tlp);
        assertTrue(tlp < t);
        assertTrue(tu > tup);
        assertTrue(tup > t);

        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);
        console.log("===========AFTER SWAPPING===========");
        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);

        rebaseModule.executeStrategies(strategyIDs);

        console.log("===========AFTER REBALANCE===========");

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);

        assertTrue(tl < tlp);
        assertTrue(tlp < t);
        assertTrue(tu > tup);
        assertTrue(tup > t);
    }

    function testGetPreferenceTicksActive3() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.DepositParams memory depositParams;

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 22e18, 0, 0);

        (, int24 tick,,,,,) = pool.slot0();

        int24 tickLower = floorTicks(tick - 550, pool.tickSpacing());
        int24 tickUpper = floorTicks(tick + 600, pool.tickSpacing());

        strategyKey.pool = pool;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;
        bytes memory data = abi.encode(300, 400, tick, tickLower, tickUpper);
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = data;

        positionActions.mode = 3;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        base.createStrategy(strategyKey, positionActions, 0, 0, false, false);

        bytes32 strategyID = getStrategyID(address(this), 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e18;
        depositParams.amount1Desired = 100e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = address(this);
        base.deposit(depositParams);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 10_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 175_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);
        console.log("===========AFTER SWAPPING===========");
        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);
        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        console.log("===========AFTER REBALANCE===========");

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);

        assertTrue(tl < tlp);
        assertTrue(tlp < t);
        assertTrue(tu > tup);
        assertTrue(tup > t);

        executeSwap(token1, token0, pool.fee(), owner, 100_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);
        console.log("===========AFTER SWAPPING===========");
        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);

        rebaseModule.executeStrategies(strategyIDs);

        console.log("===========AFTER REBALANCE===========");

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);

        assertTrue(tl < tlp);
        assertTrue(tlp < t);
        assertTrue(tu > tup);
        assertTrue(tup > t);
    }

    function testGetPreferenceTicksActive4() public {
        (, int24 tick,,,,,) = pool.slot0();

        int24 tickLower = floorTicks(tick - 550, pool.tickSpacing());
        int24 tickUpper = floorTicks(tick + 600, pool.tickSpacing());

        (bytes32 strategyID, bytes memory data, ICLTBase.PositionActions memory positionActions) =
            createActiveRebalancingAndDeposit(address(this), tick, tickLower, tickUpper, 300, 200);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 10_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 175_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);
        console.log("===========AFTER SWAPPING===========");
        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);
        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        console.log("===========AFTER REBALANCE===========");

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);

        assertTrue(tl < tlp);
        assertTrue(tlp < t);
        assertTrue(tu > tup);
        assertTrue(tup > t);

        (, tick,,,,,) = pool.slot0();
        (ICLTBase.StrategyKey memory strategyKey,,,,,,,,) = base.strategies(strategyID);

        tickLower = strategyKey.tickLower;
        tickUpper = strategyKey.tickUpper;

        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        data = abi.encode(200, 300, tick, tickLower, tickUpper);
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = data;
        positionActions.rebaseStrategy = rebaseActions;
        base.updateStrategyBase(strategyID, address(this), 0, 0, positionActions);

        console.log("===========AFTER UPDATE STRATEGY===========");

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 10_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 175_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        console.log("===========AFTER SWAPPING===========");
        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);

        console.log("===========AFTER REBALANCE===========");

        (tl, tu, tlp, tup, t) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);

        assertTrue(tl < tlp);
        assertTrue(tlp < t);
        assertTrue(tu > tup);
        assertTrue(tup > t);
    }

    function initial() internal returns (ICLTBase.PositionActions memory positionActions) {
        (, int24 tick,,,,,) = pool.slot0();
        bytes32 strategyID;
        bytes memory data;

        (strategyID, data, positionActions) = createActiveRebalancingAndDeposit(
            address(this),
            tick,
            floorTicks(tick - 550, pool.tickSpacing()),
            floorTicks(tick + 600, pool.tickSpacing()),
            300,
            200
        );

        getAllTicks(getStrategyID(address(this), 1), rebaseModule.ACTIVE_REBALANCE(), data, false);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 10_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 175_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        getAllTicks(getStrategyID(address(this), 1), rebaseModule.ACTIVE_REBALANCE(), data, false);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = getStrategyID(address(this), 1);
        rebaseModule.executeStrategies(strategyIDs);

        getAllTicks(getStrategyID(address(this), 1), rebaseModule.ACTIVE_REBALANCE(), data, false);

        ICLTBase.Account memory account;
        bytes memory actionStatus;

        (strategyKey,,, actionStatus,,,,, account) = base.strategies(getStrategyID(address(this), 1));
        (uint256 rebaseCount,,,,) = abi.decode(actionStatus, (uint256, bool, uint256, uint256, int24));

        assertTrue(rebaseCount == 1);

        IRebaseStrategy.ExectuteStrategyParams memory executeParams;
        (uint256 reserve0,) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = getStrategyID(address(this), 1);
        executeParams.tickLower = strategyKey.tickLower;
        executeParams.tickUpper = strategyKey.tickUpper;
        executeParams.shouldMint = false;
        executeParams.zeroForOne = true;
        executeParams.swapAmount = int256(reserve0 / 8);
        executeParams.sqrtPriceLimitX96 =
            (executeParams.zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1);

        rebaseModule.executeStrategy(executeParams);

        (,,, actionStatus,,,,,) = base.strategies(getStrategyID(address(this), 1));
        (rebaseCount,,,,) = abi.decode(actionStatus, (uint256, bool, uint256, uint256, int24));

        assertTrue(rebaseCount == 1);

        getAllTicks(getStrategyID(address(this), 1), rebaseModule.ACTIVE_REBALANCE(), data, true);

        executeSwap(token1, token0, pool.fee(), owner, 200_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 85_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 95_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        getAllTicks(getStrategyID(address(this), 1), rebaseModule.ACTIVE_REBALANCE(), data, true);

        rebaseModule.executeStrategies(strategyIDs);

        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(getStrategyID(address(this), 1), rebaseModule.ACTIVE_REBALANCE(), data, true);

        (,,, actionStatus,,,,,) = base.strategies(getStrategyID(address(this), 1));
        (rebaseCount,,,,) = abi.decode(actionStatus, (uint256, bool, uint256, uint256, int24));

        assertTrue(rebaseCount == 2);
        assertTrue(tl < tlp);
        assertTrue(tlp < t);
        assertTrue(tu > tup);
        assertTrue(tup > t);
    }

    function testGetPreferenceTicksActive5() public {
        (ICLTBase.PositionActions memory positionActions) = initial();
        bytes memory data =
            hex"000000000000000000000000000000000000000000000000000000000000012c00000000000000000000000000000000000000000000000000000000000000c8fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdd0000000000000000000000000000000000000000000000000000000000000024e";
        (int24 tl, int24 tu, int24 tlp, int24 tup, int24 t) =
            getAllTicks(getStrategyID(address(this), 1), rebaseModule.ACTIVE_REBALANCE(), data, false);
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        data = abi.encode(100, 100, t, tl, tu);
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = data;
        positionActions.rebaseStrategy = rebaseActions;
        base.updateStrategyBase(getStrategyID(address(this), 1), address(this), 0, 0, positionActions);

        getAllTicks(getStrategyID(address(this), 1), rebaseModule.ACTIVE_REBALANCE(), data, false);

        executeSwap(token1, token0, pool.fee(), owner, 210_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 85_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 150_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = getStrategyID(address(this), 1);
        rebaseModule.executeStrategies(strategyIDs);

        (tl, tu, tlp, tup, t) =
            getAllTicks(getStrategyID(address(this), 1), rebaseModule.ACTIVE_REBALANCE(), data, false);

        assertTrue(tl < tlp);
        assertTrue(tlp < t);
        assertTrue(tu > tup);
        assertTrue(tup > t);
    }

    // Testing the ticks calculation
    function test_Execute_Strategy_with_mode_1_tick_calculation() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        initStrategy(150);
        (, int24 tick,,,,,) = pool.slot0();
        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100, tick, strategyKey.tickLower, strategyKey.tickUpper);
        bytes32 strategyID =
            createStrategyAndDepositWithAmount(rebaseActions, 150, owner, 1, 1, false, 1000e18, 1000e18);
        console.log("Before Swapping");
        getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 17_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);
        console.log("After Swapping");
        (int24 tl, int24 tu, int24 tlp, int24 tup,) =
            getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);

        // Expected tick values calculated manually or based on understanding of the algorithm
        int24 expectedLowerThresholdTick = -60;
        int24 expectedUpperThresholdTick = 40;
        int24 expectedTl = -160;
        int24 expectedTu = 140;

        // Check if the calculated ticks are co rrect
        assertEq(tlp, expectedLowerThresholdTick, "Lower threshold tick calculation is incorrect");
        assertEq(tup, expectedUpperThresholdTick, "Upper threshold tick calculation is incorrect");
        assertEq(tl, expectedTl, "TLP tick calculation is incorrect");
        assertEq(tu, expectedTu, "TUP tick calculation is incorrect");
        console.log("During Swapping");

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);
        console.log("After Rebalance");

        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        (, tick,,,,,) = pool.slot0();
        // -220 + (100 - ((-1-(-160)) - (-62-(-220))))
        expectedLowerThresholdTick = -121;
        // 80 - (100 + ((140 -( -1)) - (80 - (-62))))
        expectedUpperThresholdTick = -19;
        expectedTl = floorTicks((-212), pool.tickSpacing());
        expectedTu = floorTicks(88, pool.tickSpacing());

        // Check if the calculated ticks are co rrect
        assertEq(tlp, expectedLowerThresholdTick, "Lower threshold tick calculation is incorrect");
        assertEq(tup, expectedUpperThresholdTick, "Upper threshold tick calculation is incorrect");
        assertEq(tl, expectedTl, "TL tick calculation is incorrect");
        assertEq(tu, expectedTu, "TU tick calculation is incorrect");

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 17_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);
        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseActions[0].actionName, rebaseActions[0].data, false);
        (, tick,,,,,) = pool.slot0();
        expectedTl = floorTicks((-274), pool.tickSpacing());
        expectedTu = floorTicks(26, pool.tickSpacing());
        expectedLowerThresholdTick = expectedTl + 99;
        expectedUpperThresholdTick = expectedTu - 99;

        // adjusted Difference0 = 99
        // adjusted Difference0 = 99

        assertEq(tlp, expectedLowerThresholdTick, "Lower threshold tick calculation is incorrect");
        assertEq(tup, expectedUpperThresholdTick, "Upper threshold tick calculation is incorrect");
        assertEq(tl, expectedTl, "TL tick calculation is incorrect");
        assertEq(tu, expectedTu, "TU tick calculation is incorrect");
    }

    function test_Execute_Strategy_with_mode_1_tick_calculation_2() public {
        // initStrategy(150);
        ICLTBase.PositionActions memory positionActions;
        (, int24 tick,,,,,) = pool.slot0();
        bytes32 strategyID;
        bytes memory data;
        (strategyID, data, positionActions) = createActiveRebalancingAndDeposit(
            address(this),
            tick,
            floorTicks(tick - 700, pool.tickSpacing()),
            floorTicks(tick + 300, pool.tickSpacing()),
            500,
            200
        );

        console.log("Before Swapping");
        getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 170_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        console.log("After Swapping");
        (int24 tl, int24 tu, int24 tlp, int24 tup,) =
            getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);

        // Expected tick values calculated manually or based on understanding of the algorithm
        int24 expectedLowerThresholdTick = -710 + 500;
        int24 expectedUpperThresholdTick = 290 - 200;
        int24 expectedTl = -710;
        int24 expectedTu = 290;

        // Check if the calculated ticks are co rrect
        assertEq(tlp, expectedLowerThresholdTick, "Lower threshold tick calculation is incorrect");
        assertEq(tup, expectedUpperThresholdTick, "Upper threshold tick calculation is incorrect");
        assertEq(tl, expectedTl, "TLP tick calculation is incorrect");
        assertEq(tu, expectedTu, "TUP tick calculation is incorrect");

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);
        console.log("After Rebalance");
        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);
        (, tick,,,,,) = pool.slot0();
        // -870 + (500 - ((-1-(-710)) - (-365-(-870))))
        expectedLowerThresholdTick = -574;
        // 130 + (200 + ((290 - (-1)) - (130 - (-365))))
        expectedUpperThresholdTick = 126;
        expectedTl = floorTicks((-865), pool.tickSpacing());
        expectedTu = floorTicks(135, pool.tickSpacing());

        // Check if the calculated ticks are co rrect
        assertEq(tlp, expectedLowerThresholdTick, "Lower threshold tick calculation is incorrect");
        assertEq(tup, expectedUpperThresholdTick, "Upper threshold tick calculation is incorrect");
        assertEq(tl, expectedTl, "TL tick calculation is incorrect");
        assertEq(tu, expectedTu, "TU tick calculation is incorrect");

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 130_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        ICLTBase.Account memory account;

        (strategyKey,,,,,,,, account) = base.strategies(getStrategyID(address(this), 1));
        IRebaseStrategy.ExectuteStrategyParams memory executeParams;
        (uint256 reserve0,) = getStrategyReserves(strategyKey, account.uniswapLiquidity);

        executeParams.pool = strategyKey.pool;
        executeParams.strategyID = getStrategyID(address(this), 1);
        executeParams.tickLower = strategyKey.tickLower;
        executeParams.tickUpper = strategyKey.tickUpper;
        executeParams.shouldMint = false;
        executeParams.zeroForOne = true;
        executeParams.swapAmount = int256(reserve0 / 8);
        executeParams.sqrtPriceLimitX96 =
            (executeParams.zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1);

        rebaseModule.executeStrategy(executeParams);

        // (,,, bytes memory actionStatus,,,,,) = base.strategies(getStrategyID(address(this), 1));
        // (,,,,, expectedLowerThresholdTick, expectedUpperThresholdTick) =
        //     abi.decode(actionStatus, (uint256, bool, uint256, uint256, int24, int24, int24));

        // assertTrue(expectedLowerThresholdTick == 296);
        // assertTrue(expectedUpperThresholdTick == -4);

        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);
        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);
        (, tick,,,,,) = pool.slot0();
        expectedTl = floorTicks((-1146), pool.tickSpacing());
        expectedTu = floorTicks(-146, pool.tickSpacing());
        expectedLowerThresholdTick = expectedTl + 296;
        expectedUpperThresholdTick = expectedTu + (-4);

        // adjusted Difference0 = 296
        // adjusted Difference0 = -4

        assertEq(tlp, expectedLowerThresholdTick, "Lower threshold tick calculation is incorrect");
        assertEq(tup, expectedUpperThresholdTick, "Upper threshold tick calculation is incorrect");
        assertEq(tl, expectedTl, "TL tick calculation is incorrect");
        assertEq(tu, expectedTu, "TU tick calculation is incorrect");
    }

    function test_Execute_Strategy_with_mode_2_tick_calculation() public {
        ICLTBase.PositionActions memory positionActions;
        (, int24 tick,,,,,) = pool.slot0();
        bytes32 strategyID;
        bytes memory data;
        (strategyID, data, positionActions) = createActiveRebalancingAndDeposit(
            address(this),
            tick,
            floorTicks(tick - 700, pool.tickSpacing()),
            floorTicks(tick + 300, pool.tickSpacing()),
            500,
            200
        );

        console.log("Before Swapping");
        getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 35_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        console.log("After Swapping");
        (int24 tl, int24 tu, int24 tlp, int24 tup,) =
            getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);

        // Expected tick values calculated manually or based on understanding of the algorithm
        int24 expectedLowerThresholdTick = -710 + 500;
        int24 expectedUpperThresholdTick = 290 - 200;
        int24 expectedTl = -710;
        int24 expectedTu = 290;

        // Check if the calculated ticks are co rrect
        assertEq(tlp, expectedLowerThresholdTick, "Lower threshold tick calculation is incorrect");
        assertEq(tup, expectedUpperThresholdTick, "Upper threshold tick calculation is incorrect");
        assertEq(tl, expectedTl, "TLP tick calculation is incorrect");
        assertEq(tu, expectedTu, "TUP tick calculation is incorrect");

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);
        console.log("After Rebalance");
        (tl, tu, tlp, tup,) = getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, false);
        (, tick,,,,,) = pool.slot0();
        // -410 + (500 - ((-1-(-710)) - (98-(-410)))
        expectedLowerThresholdTick = -111;
        // 590 + (200 + ((290 - (-1)) - (590 - (98))))
        expectedUpperThresholdTick = 589;
        expectedTl = floorTicks((-402), pool.tickSpacing());
        expectedTu = floorTicks(598, pool.tickSpacing());

        // Check if the calculated ticks are co rrect
        assertEq(tlp, expectedLowerThresholdTick, "Lower threshold tick calculation is incorrect");
        assertEq(tup, expectedUpperThresholdTick, "Upper threshold tick calculation is incorrect");
        assertEq(tl, expectedTl, "TL tick calculation is incorrect");
        assertEq(tu, expectedTu, "TU tick calculation is incorrect");

        (,,, bytes memory actionStatus,,,,,) = base.strategies(getStrategyID(address(this), 1));
        (,,,,, expectedLowerThresholdTick, expectedUpperThresholdTick) =
            abi.decode(actionStatus, (uint256, bool, uint256, uint256, int24, int24, int24));

        assertTrue(expectedLowerThresholdTick == 299);
        assertTrue(expectedUpperThresholdTick == -1);
    }

    function test_Execute_Strategy_with_mode_3_Debug() public {
        ICLTBase.PositionActions memory positionActions;
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 35_000e18, 0, 0);

        (, int24 tick,,,,,) = pool.slot0();
        bytes32 strategyID;
        bytes memory data;
        (strategyID, data, positionActions) = createActiveRebalancingAndDeposit(
            address(this),
            tick,
            floorTicks(tick - 700, pool.tickSpacing()),
            floorTicks(tick + 300, pool.tickSpacing()),
            100,
            280
        );

        console.log("Before Swapping");
        getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 15_000e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 300_000e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        console.log("After Swapping");
        // (int24 tl, int24 tu, int24 tlp, int24 tup,) =
        getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);

        // // Expected tick values calculated manually or based on understanding of the algorithm
        // int24 expectedLowerThresholdTick = -710 + 500;
        // int24 expectedUpperThresholdTick = 290 - 200;
        // int24 expectedTl = -710;
        // int24 expectedTu = 290;

        // // Check if the calculated ticks are co rrect
        // assertEq(tlp, expectedLowerThresholdTick, "Lower threshold tick calculation is incorrect");
        // assertEq(tup, expectedUpperThresholdTick, "Upper threshold tick calculation is incorrect");
        // assertEq(tl, expectedTl, "TLP tick calculation is incorrect");
        // assertEq(tu, expectedTu, "TUP tick calculation is incorrect");

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);
        console.log("After Rebalance");
        getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);
        // (, tick,,,,,) = pool.slot0();
        // // -410 + (500 - ((-1-(-710)) - (98-(-410)))
        // expectedLowerThresholdTick = -111;
        // // 590 + (200 + ((290 - (-1)) - (590 - (98))))
        // expectedUpperThresholdTick = 589;
        // expectedTl = floorTicks((-402), pool.tickSpacing());
        // expectedTu = floorTicks(598, pool.tickSpacing());

        // // Check if the calculated ticks are co rrect
        // assertEq(tlp, expectedLowerThresholdTick, "Lower threshold tick calculation is incorrect");
        // assertEq(tup, expectedUpperThresholdTick, "Upper threshold tick calculation is incorrect");
        // assertEq(tl, expectedTl, "TL tick calculation is incorrect");
        // assertEq(tu, expectedTu, "TU tick calculation is incorrect");

        // (,,, bytes memory actionStatus,,,,,) = base.strategies(getStrategyID(address(this), 1));
        // (,,,,, expectedLowerThresholdTick, expectedUpperThresholdTick) =
        //     abi.decode(actionStatus, (uint256, bool, uint256, uint256, int24, int24, int24));

        // assertTrue(expectedLowerThresholdTick == 299);
        // assertTrue(expectedUpperThresholdTick == -1);
    }
}
