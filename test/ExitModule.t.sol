// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ExitFixtures } from "./utils/ExitFixtures.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { PoolActions } from "../src/libraries/PoolActions.sol";
import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";

import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";

contract ExitModuleTest is Test, ExitFixtures {
    address payable[] users;
    address owner;

    function setUp() public {
        users = createUsers(5);
        owner = address(this);
        initBase(owner, 10_000_000e18, 10_000_000e18);
    }

    function testCreateExitStraetgy() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory exitActions = new ICLTBase.StrategyPayload[](1);
        exitActions[0].actionName = exitModule.EXIT_PREFERENCE();
        exitActions[0].data = abi.encode(strategyKey.tickLower - 700, strategyKey.tickUpper + 300);

        positionActions.mode = 2;
        positionActions.exitStrategy = exitActions;
        positionActions.rebaseStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, true, positionActions);
    }

    function testFail_CreateExitStrategyInvalidData() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory exitActions = new ICLTBase.StrategyPayload[](1);
        exitActions[0].actionName = exitModule.EXIT_PREFERENCE();
        exitActions[0].data = abi.encode(strategyKey.tickLower + 700, strategyKey.tickUpper + 300);

        positionActions.mode = 2;
        positionActions.exitStrategy = exitActions;
        positionActions.rebaseStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, true, positionActions);
    }

    function testFail_CreateExitStrategyInvalidData2() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory exitActions = new ICLTBase.StrategyPayload[](1);
        exitActions[0].actionName = exitModule.EXIT_PREFERENCE();
        exitActions[0].data = abi.encode(strategyKey.tickLower + 1, strategyKey.tickLower + 1);

        positionActions.mode = 2;
        positionActions.exitStrategy = exitActions;
        positionActions.rebaseStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, true, positionActions);
    }

    function testFail_CreateExitStrategyInvalidData3() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory exitActions = new ICLTBase.StrategyPayload[](1);
        exitActions[0].actionName = exitModule.EXIT_PREFERENCE();
        exitActions[0].data = "";

        positionActions.mode = 2;
        positionActions.exitStrategy = exitActions;
        positionActions.rebaseStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, true, positionActions);
    }

    function test_ExecuteExitStrategySuccessUpper() public {
        ICLTBase.StrategyPayload[] memory exitActions = new ICLTBase.StrategyPayload[](1);
        exitActions[0].actionName = exitModule.EXIT_PREFERENCE();
        exitActions[0].data = abi.encode(strategyKey.tickLower - 700, strategyKey.tickUpper + 300);
        bytes32 strategyID =
            createStrategyAndDeposit(exitActions, new ICLTBase.StrategyPayload[](0), 100, address(this), 1, 3, true);

        getAllTicks(strategyID, abi.encode(strategyKey.tickLower - 700, strategyKey.tickUpper + 300), true);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 200_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        getAllTicks(strategyID, abi.encode(strategyKey.tickLower - 700, strategyKey.tickUpper + 300), true);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        exitModule.executeExit(strategyIDs);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertTrue(account.uniswapLiquidity == 0);
        assertTrue(account.totalShares > 0);

        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: account.totalShares,
                recipient: address(this),
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );
        (,,,,,,,, account) = base.strategies(strategyID);
        assertTrue(account.totalShares == 0);
    }

    function test_ExecuteExitStrategySuccessLower() public {
        ICLTBase.StrategyPayload[] memory exitActions = new ICLTBase.StrategyPayload[](1);
        exitActions[0].actionName = exitModule.EXIT_PREFERENCE();
        exitActions[0].data = abi.encode(strategyKey.tickLower - 700, strategyKey.tickUpper + 300);
        bytes32 strategyID =
            createStrategyAndDeposit(exitActions, new ICLTBase.StrategyPayload[](0), 100, address(this), 1, 3, true);

        getAllTicks(strategyID, abi.encode(strategyKey.tickLower - 700, strategyKey.tickUpper + 300), true);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 200_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 300_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        getAllTicks(strategyID, abi.encode(strategyKey.tickLower - 700, strategyKey.tickUpper + 300), true);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        exitModule.executeExit(strategyIDs);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertTrue(account.uniswapLiquidity == 0);
        assertTrue(account.totalShares > 0);

        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 1,
                liquidity: account.totalShares,
                recipient: address(this),
                refundAsETH: true,
                amount0Min: 0,
                amount1Min: 0
            })
        );
        (,,,,,,,, account) = base.strategies(strategyID);
        assertTrue(account.totalShares == 0);
    }

    function test_ExecuteExitStrategy_Lower_remint() public {
        ICLTBase.StrategyPayload[] memory exitActions = new ICLTBase.StrategyPayload[](1);
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        exitActions[0].actionName = exitModule.EXIT_PREFERENCE();
        exitActions[0].data = abi.encode(strategyKey.tickLower - 700, strategyKey.tickUpper + 300);

        bytes32 strategyID = createStrategyAndDeposit(exitActions, rebaseActions, 100, address(this), 1, 3, true);

        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 200_000e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 300_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        exitModule.executeExit(strategyIDs);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertTrue(account.uniswapLiquidity == 0);
        assertTrue(account.totalShares > 0);

        // should not rebalance it
        rebaseModule.executeStrategies(strategyIDs);

        (,,,,,,,, account) = base.strategies(strategyID);
        assertTrue(account.uniswapLiquidity == 0);
        assertTrue(account.totalShares > 0);
    }

    function test_ExecuteExitStrategy_Upper_remint() public {
        ICLTBase.StrategyPayload[] memory exitActions = new ICLTBase.StrategyPayload[](1);
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        exitActions[0].actionName = exitModule.EXIT_PREFERENCE();
        exitActions[0].data = abi.encode(strategyKey.tickLower - 700, strategyKey.tickUpper + 300);

        bytes32 strategyID = createStrategyAndDeposit(exitActions, rebaseActions, 100, address(this), 1, 3, true);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 200_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        exitModule.executeExit(strategyIDs);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertTrue(account.uniswapLiquidity == 0);
        assertTrue(account.totalShares > 0);

        // should not rebalance it
        rebaseModule.executeStrategies(strategyIDs);

        (,,,,,,,, account) = base.strategies(strategyID);
        assertTrue(account.uniswapLiquidity == 0);
        assertTrue(account.totalShares > 0);
    }

    function test_ExecuteExitStrategy_withRebasePricePreference() public {
        ICLTBase.StrategyPayload[] memory exitActions = new ICLTBase.StrategyPayload[](1);
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        exitActions[0].actionName = exitModule.EXIT_PREFERENCE();
        exitActions[0].data = abi.encode(strategyKey.tickLower - 700, strategyKey.tickUpper + 300);

        bytes32 strategyID = createStrategyAndDeposit(exitActions, rebaseActions, 100, address(this), 1, 3, true);

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 20_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // should not eixt
        bytes32[] memory strategyIDs = new bytes32[](1);
        strategyIDs[0] = strategyID;
        exitModule.executeExit(strategyIDs);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        assertTrue(account.uniswapLiquidity > 0);
        assertTrue(account.totalShares > 0);

        // should rebalance it
        rebaseModule.executeStrategies(strategyIDs);

        (,,,,,,,, account) = base.strategies(strategyID);
        (int24 tlp, int24 tup,,) =
            rebaseModule.getPreferenceTicks(strategyID, rebaseModule.PRICE_PREFERENCE(), abi.encode(10, 30));

        (,,,,,,,, account) = base.strategies(strategyID);
        assertTrue(account.uniswapLiquidity > 0, "Uniswap liqudity cannot be zero");
        assertTrue(account.totalShares > 0, "Liquidity shares cannot be zero");
        assertTrue(tlp != 10, "Incorrect Price ranges");
        assertTrue(tup != 30, "Incorrect Price ranges");

        executeSwap(token1, token0, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 100e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 400e18, 0, 0);
        executeSwap(token1, token0, pool.fee(), owner, 200_000e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);
        _hevm.roll(1 days);

        // should eixt now
        strategyIDs[0] = strategyID;
        exitModule.executeExit(strategyIDs);
        (,,,,,,,, account) = base.strategies(strategyID);
        assertTrue(account.uniswapLiquidity == 0, "Uniswap liqudity cannot be greater than zero");
        assertTrue(account.totalShares > 0, "Liquidity shares cannot be zero");
    }
}
