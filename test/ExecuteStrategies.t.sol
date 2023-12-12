// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { RebaseFixtures } from "./utils/RebaseModuleFixtures.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";

contract ExecuteStrategiesTest is Test, RebaseFixtures {
    address payable[] users;
    address owner;

    function setUp() public {
        users = createUsers(5);
        owner = address(this);
        initBase(owner);
    }

    function testCreateStrategy() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        positionActions.mode = 2;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(1500, owner, true, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);
        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID);

        assertEq(address(strategyKey.pool), address(key.pool));
    }

    function testDepositInAlp() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        bytes32 strategyId = createStrategyAndDeposit(rebaseActions, 1500, owner, 1, 1, true);
        (bytes32 _strategyId,,,,,) = base.positions(1);
        assertEq(_strategyId, strategyId);
    }

    function testExecuteStrategyWithValidStrategyID() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        bytes32 strategyId = createStrategyAndDeposit(rebaseActions, 1500, owner, 1, 1, true);

        bytes32[] memory strategyIDs = new bytes32[]( 1);

        strategyIDs[0] = strategyId;

        generateMultipleSwapsWithTime(owner);

        rebaseModule.executeStrategies(strategyIDs);
        (bytes32 strategyID,,,,,) = base.positions(1);
        assertEq(strategyID, strategyId);
    }

    function testExecutingStrategyWithEmptyID() public {
        bytes32[] memory strategyIDs = new bytes32[]( 10);
        vm.expectRevert();
        rebaseModule.executeStrategies(strategyIDs);
    }

    function testExecuteStrategyWithStrategyIDDonotExist() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 43);

        createStrategyAndDeposit(rebaseActions, 1500, owner, 1, 1, true);

        bytes32[] memory strategyIDs = new bytes32[]( 1);

        bytes32 strategyID = keccak256(abi.encode(users[2], 1));

        strategyIDs[0] = strategyID;

        vm.expectRevert();
        rebaseModule.executeStrategies(strategyIDs);
    }

    function testExecuteStrategyWithZeroStrategyID() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 43);

        createStrategyAndDeposit(rebaseActions, 1500, owner, 1, 1, true);

        bytes32[] memory strategyIDs = new bytes32[]( 1);

        bytes32 strategyID = bytes32(0);

        strategyIDs[0] = strategyID;

        bytes memory encodedError = abi.encodeWithSignature("InvalidStrategyId(bytes32)", strategyID);
        vm.expectRevert(encodedError);
        rebaseModule.executeStrategies(strategyIDs);
    }

    function testExecuteStrategiesWithLargeStrategiesArrays() public { }

    // edge
    // 5
    function test_fuzz_ExecuteStrategyAllModesWithOnlyRebaseInactivity(uint256 mode) public {
        vm.assume(mode >= 1 && mode <= 3);
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[0].data = abi.encode(3);

        bytes32 strategyID = createStrategyAndDeposit(rebaseActions, 1500, owner, 1, mode, true);

        bytes32[] memory strategyIDs = new bytes32[]( 1);

        strategyIDs[0] = strategyID;

        (ICLTBase.StrategyKey memory keyBefore,,,,,,,,) = base.strategies(strategyID);

        rebaseModule.executeStrategies(strategyIDs);

        (ICLTBase.StrategyKey memory keyAfter,,,,,,,,) = base.strategies(strategyID);

        assertEq(keyBefore.tickLower, keyAfter.tickLower);
        assertEq(keyBefore.tickUpper, keyAfter.tickUpper);
    }

    // 6
    function testExecuteStrategyAllModesWithRebaseInactivityAndPrice() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 1500, owner, 1, 1, true);

        executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        // for mode 2
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(45, 22);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(1);

        bytes32 strategyID2 = createStrategyAndDeposit(rebaseActions, 3000, owner, 2, 2, true);

        executeSwap(token1, token0, pool.fee(), owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        strategyIDs[0] = strategyID2;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID2);
        assertEq(abi.decode(actionStatus, (uint256)), 1);

        // for mode 3
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(76, 2);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(1);

        bytes32 strategyID3 = createStrategyAndDeposit(rebaseActions, 1700, owner, 3, 3, true);

        executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        strategyIDs[0] = strategyID3;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID3);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        // for mode 3
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(34, 11);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(1);

        bytes32 strategyID4 = createStrategyAndDeposit(rebaseActions, 500, owner, 4, 3, true);

        executeSwap(token1, token0, pool.fee(), owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        strategyIDs[0] = strategyID4;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID4);

        assertEq(abi.decode(actionStatus, (uint256)), 1);
    }

    function testExecuteStrategyShouldNotRebasePastLimitMode1() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 1500, owner, 1, 1, true);

        executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);

        executeSwap(token0, token1, pool.fee(), owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);
    }

    function testExecuteStrategyShouldNotRebasePastLimitMode2() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 700, owner, 1, 2, true);

        executeSwap(token1, token0, pool.fee(), owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        executeSwap(token1, token0, pool.fee(), owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);

        executeSwap(token1, token0, pool.fee(), owner, 150e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);
    }

    function testExecuteStrategyShouldNotRebasePastLimitMode3() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 700, owner, 1, 3, true);

        executeSwap(token1, token0, pool.fee(), owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        executeSwap(token0, token1, pool.fee(), owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);

        executeSwap(token1, token0, pool.fee(), owner, 150e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);
    }

    function testExecuteStrategyShouldWithOutOfRangeOnTheValidSideMode1() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 700, owner, 1, 1, true);

        executeSwap(token0, token1, pool.fee(), owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        executeSwap(token0, token1, pool.fee(), owner, 150e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);

        executeSwap(token0, token1, pool.fee(), owner, 150e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);
    }

    function testExecuteStrategyShouldWithOutOfRangeOnTheValidSideMode2() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 700, owner, 1, 2, true);

        executeSwap(token1, token0, pool.fee(), owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        executeSwap(token1, token0, pool.fee(), owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);

        executeSwap(token1, token0, pool.fee(), owner, 150e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);
    }

    function testExecuteStrategyShouldWithOutOfRangeOnTheInValidSideMode1() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 700, owner, 1, 1, true);

        executeSwap(token1, token0, pool.fee(), owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);
        assertEq(actionStatus, "");
    }

    function testExecuteStrategyShouldWithOutOfRangeOnTheInValidSideMode2() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 700, owner, 1, 2, true);

        executeSwap(token0, token1, pool.fee(), owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);
        assertEq(actionStatus, "");
    }

    function testExecuteStrategyWithMaximumTicks() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(887_272, 887_272);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 700, owner, 1, 2, true);

        executeSwap(token0, token1, pool.fee(), owner, 1500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);
        assertEq(actionStatus, "");
    }

    function testMultipleExecuteStrategy() public {
        bytes32[] memory strategyIDs = new bytes32[](10);

        for (uint256 i = 0; i < 10; i++) {
            uint256 randomValue1 = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, i))) % 1000;

            uint256 randomValue2 =
                uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, i, "second"))) % 1000;

            int24 depositAmount = int24(
                int256(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, i, "deposit"))) % 1000 + 1)
            );

            uint256 mode = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, i, "last"))) % 3 + 1;

            ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
            rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
            rebaseActions[0].data = abi.encode(randomValue1, randomValue2);
            rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
            rebaseActions[1].data = abi.encode(mode);

            bytes32 strategyID = createStrategyAndDeposit(rebaseActions, depositAmount, owner, i + 1, mode, true);

            if (mode == 1) {
                executeSwap(token1, token0, pool.fee(), owner, 150e18, 0, 0);
            } else if (mode == 2) {
                executeSwap(token0, token1, pool.fee(), owner, 150e18, 0, 0);
            } else {
                executeSwap(token0, token1, pool.fee(), owner, 150e18, 0, 0);
            }
            strategyIDs[i] = strategyID;
        }

        rebaseModule.executeStrategies(strategyIDs);
    }
}
