// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { RebaseFixtures } from "./utils/RebaseFixtures.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { PoolActions } from "../src/libraries/PoolActions.sol";

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { PositionKey } from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { LiquidityAmounts } from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";

contract ActiveRebalancingTest is Test, RebaseFixtures {
    address payable[] users;
    address owner;

    function setUp() public {
        users = createUsers(5);
        owner = address(this);
        initBase(owner);
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

        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(1000, 1000);

        positionActions.mode = 3;
        positionActions.rebaseStrategy = rebaseActions;

        bytes32 strategyID = createStrategyAndDeposit(rebaseActions, 1500, owner, 1, 3, false);

        (ICLTBase.StrategyKey memory key,, bytes memory actionsData,,,,,, ICLTBase.Account memory account) =
            base.strategies(strategyID);
        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        (int24 lowerPreferenceTick, int24 upperPreferenceTick) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), rebaseActions[0].data);

        (, int24 tick,,,,,) = pool.slot0();
        assertEq(address(key.pool), address(key.pool));

        console.logInt(key.tickLower);
        console.logInt(lowerPreferenceTick);
        console.logInt(tick);
        console.logInt(upperPreferenceTick);
        console.logInt(key.tickUpper);

        // do a small swap
        executeSwap(token0, token1, pool.fee(), owner, 200e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        (key,, actionsData,,,,,,) = base.strategies(strategyID);
        (lowerPreferenceTick, upperPreferenceTick) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), rebaseActions[0].data);
        (, tick,,,,,) = pool.slot0();
        assertEq(address(strategyKey.pool), address(key.pool));
        console.log("========================");

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;

        rebaseModule.executeStrategies(strategyIDs);
        (lowerPreferenceTick, upperPreferenceTick) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), rebaseActions[0].data);
        (key,,,,,,,, account) = base.strategies(strategyID);
        console.log("========================");

        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);
        console.log(account.balance0);
        console.log(account.balance1);
        console.log(reserve0);
        console.log(reserve1);

        // console.logInt(key.tickLower);
        // console.logInt(lowerPreferenceTick);
        // console.logInt(tick);
        // console.logInt(upperPreferenceTick);
        // console.logInt(key.tickUpper);
    }

    function testCreateStrategyARPartial() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[1].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[1].data = abi.encode(10, 30);

        rebaseActions[0].actionName = rebaseModule.ACTIVE_REBALANCE();
        rebaseActions[0].data = abi.encode(100, 100);

        positionActions.mode = 3;
        positionActions.rebaseStrategy = rebaseActions;

        bytes32 strategyID = createStrategyAndDeposit(rebaseActions, 150, owner, 1, 3, false);

        (ICLTBase.StrategyKey memory key,, bytes memory actionsData,,,,,, ICLTBase.Account memory account) =
            base.strategies(strategyID);

        (int24 lowerPreferenceTick, int24 upperPreferenceTick) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), rebaseActions[0].data);

        (, int24 tick,,,,,) = pool.slot0();

        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, account.uniswapLiquidity);

        console.log("Balance0", account.balance0);
        console.log("Balance1", account.balance1);
        console.log("Reserve0", reserve0);
        console.log("Reserve1", reserve1);

        assertEq(address(key.pool), address(key.pool));
        _hevm.warp(block.timestamp + 3600);

        (uint128 liquidity,,,,) = getPositionLiquidity(key);

        console.log("========================");

        // do a small swap
        executeSwap(token0, token1, pool.fee(), owner, 70e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 170e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 670e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 170e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(block.timestamp + 1 days);

        (, tick,,,,,) = pool.slot0();

        // console.logInt(key.tickLower);
        // console.logInt(lowerPreferenceTick);
        // console.logInt(tick);
        // console.logInt(upperPreferenceTick);
        // console.logInt(key.tickUpper);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        rebaseModule.executeStrategies(strategyIDs);
        (key,, actionsData,,,,,,) = base.strategies(strategyID);

        (lowerPreferenceTick, upperPreferenceTick) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), rebaseActions[0].data);
        console.log("========================");

        (key,,,,,,,, account) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, account.uniswapLiquidity);
        console.log(account.balance0);
        console.log(account.balance1);
        console.log(reserve0);
        console.log(reserve1);
    }
}
