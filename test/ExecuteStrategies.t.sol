// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { RebaseFixtures } from "./utils/RebaseModuleFixtures.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IPreference } from "../src/interfaces/modules/IPreference.sol";
import { console } from "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";

contract ExecuteStrategiesTest is Test, RebaseFixtures {
    IUniswapV3Pool poolContract;
    CLTBase baseContract;

    address payable[] users;
    address owner;

    function setUp() public {
        users = createUsers(5);
        owner = address(this);
        (baseContract, poolContract) = initBase(owner);
    }

    function testCreateStrategy() public {
        ICLTBase.PositionActions memory positionActions;
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        positionActions.mode = positionActions.mode;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(baseContract, poolContract, 1500, owner, positionActions);

        bytes32 strategyID = getStrategyID(owner, 1);
        (ICLTBase.StrategyKey memory key,,,,,,) = baseContract.strategies(strategyID);

        assertEq(address(strategyKey.pool), address(key.pool));
    }

    function testDepositInAlp() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        bytes32 strategyId = createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 1, 1);
        (bytes32 _strategyId,,,,,) = baseContract.positions(1);
        assertEq(_strategyId, strategyId);
    }

    function testFunctionByNonOperator() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        bytes32 strategyId = createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 1, 1);

        bytes32[] memory strategyIDs = new bytes32[]( 1);

        strategyIDs[0] = strategyId;

        vm.expectRevert();
        rebaseModule.executeStrategies(strategyIDs);
    }

    function testExecuteStrategyWithValidStrategyID() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        bytes32 strategyId = createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 1, 1);

        bytes32[] memory strategyIDs = new bytes32[]( 1);

        strategyIDs[0] = strategyId;

        generateMultipleSwapsWithTime(owner);

        rebaseModule.executeStrategies(strategyIDs);
        (bytes32 strategyID,,,,,) = baseContract.positions(1);
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

        createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 1, 1);

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

        createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 1, 1);

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

        bytes32 strategyID = createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 1, mode);

        bytes32[] memory strategyIDs = new bytes32[]( 1);

        strategyIDs[0] = strategyID;

        (ICLTBase.StrategyKey memory keyBefore,,,,,,) = baseContract.strategies(strategyID);

        rebaseModule.executeStrategies(strategyIDs);

        (ICLTBase.StrategyKey memory keyAfter,,,,,,) = baseContract.strategies(strategyID);

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

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 1, 1);

        executeSwap(token0, token1, poolContract.fee(), owner, 100e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,) = baseContract.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        // // for mode 2
        // rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        // rebaseActions[0].data = abi.encode(45, 22);

        // rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        // rebaseActions[1].data = abi.encode(1);

        // _hevm.warp(block.timestamp + 3600);
        // executeSwap(token1, token0, poolContract.fee(), owner, 500e18, 0, 0);
        // _hevm.warp(block.timestamp + 3600);

        // bytes32 strategyID2 = createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 2, 2);

        // strategyIDs[0] = strategyID2;

        // rebaseModule.executeStrategies(strategyIDs);
        // (,,, actionStatus,,,) = baseContract.strategies(strategyID);

        // (,,, bytes memory actionStatus,,,,,,,) = baseContract.strategies(strategyID2);
        // console.logBytes(actionStatus);
        // assertEq(abi.decode(actionStatus, (uint256)), 1);

        // // for mode 3
        // rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        // rebaseActions[0].data = abi.encode(76, 2);

        // rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        // rebaseActions[1].data = abi.encode(1);

        // _hevm.warp(block.timestamp + 3600);
        // executeSwap(token0, token1, poolContract.fee(), owner, 200e18, 0, 0);
        // _hevm.warp(block.timestamp + 3600);

        // bytes32 strategyID3 = createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 3, 3);

        // strategyIDs[0] = strategyID3;

        // rebaseModule.executeStrategies(strategyIDs);

        // (,,, actionStatus,,,,,,,) = baseContract.strategies(strategyID3);

        // assertEq(abi.decode(actionStatus, (uint256)), 1);

        // // for mode 3
        // rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        // rebaseActions[0].data = abi.encode(34, 11);

        // rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        // rebaseActions[1].data = abi.encode(1);

        // _hevm.warp(block.timestamp + 3600);
        // executeSwap(token1, token0, poolContract.fee(), owner, 200e18, 0, 0);
        // _hevm.warp(block.timestamp + 3600);

        // bytes32 strategyID4 = createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 4, 3);

        // strategyIDs[0] = strategyID4;

        // rebaseModule.executeStrategies(strategyIDs);

        // (,,, actionStatus,,,,,,,) = baseContract.strategies(strategyID4);

        // assertEq(abi.decode(actionStatus, (uint256)), 1);
    }
}