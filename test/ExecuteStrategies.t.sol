// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import { RebaseFixtures } from "./utils/RebaseFixtures.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { IAlgebraPool } from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";
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

    /*
     * check input data test cases
     */

    // Price Preference
    function test_fuzz_pricePreferenceWithValidInputs(uint256 amount0, uint256 amount1) public view {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModule.PRICE_PREFERENCE();

        vm.assume(amount0 > 0 && amount0 < 8_388_608 && amount1 < 8_388_608 && amount1 > 0);
        strategyDetail.data = abi.encode(uint256(amount0), uint256(amount1));
        rebaseModule.checkInputData(strategyDetail);
    }

    function test_fuzz_pricePreferenceWithLowerPriceZero(uint256 amount1) public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModule.PRICE_PREFERENCE();

        vm.assume(amount1 < 8_388_608 && amount1 > 0);
        strategyDetail.data = abi.encode(uint256(0), uint256(30));
        bytes4 selector = bytes4(keccak256("InvalidPricePreferenceDifference()"));
        _hevm.expectRevert(selector);
        rebaseModule.checkInputData(strategyDetail);
    }

    function test_fuzz_pricePreferenceWithUpperPriceZero(uint256 amount0) public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModule.PRICE_PREFERENCE();

        vm.assume(amount0 < 8_388_608 && amount0 > 0);
        strategyDetail.data = abi.encode(uint256(amount0), uint256(0));
        bytes4 selector = bytes4(keccak256("InvalidPricePreferenceDifference()"));
        _hevm.expectRevert(selector);
        rebaseModule.checkInputData(strategyDetail);
    }

    function testPricePreferenceWithBothPriceZero() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModule.PRICE_PREFERENCE();
        strategyDetail.data = abi.encode(uint256(0), uint256(0));
        _hevm.expectRevert();
        rebaseModule.checkInputData(strategyDetail);
    }

    function testPricePreferenceWithZeroData() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModule.PRICE_PREFERENCE();
        strategyDetail.data = "";
        _hevm.expectRevert();
        rebaseModule.checkInputData(strategyDetail);
    }

    // Rebase Inactivity

    function testInputDataRebaseInActivityWithValidInputs(uint256 amount) public {
        ICLTBase.StrategyPayload memory strategyDetail;
        vm.assume(amount > 0);
        strategyDetail.data = abi.encode(uint256(amount));
        strategyDetail.actionName = rebaseModule.REBASE_INACTIVITY();
        assertTrue(rebaseModule.checkInputData(strategyDetail));
    }

    function testInputDataRebaseInActivityWithInValidInputs() public {
        ICLTBase.StrategyPayload memory strategyDetail;
        strategyDetail.actionName = rebaseModule.REBASE_INACTIVITY();
        strategyDetail.data = abi.encode(uint256(0));

        bytes4 selector = bytes4(keccak256("RebaseInactivityCannotBeZero()"));
        _hevm.expectRevert(selector);
        rebaseModule.checkInputData(strategyDetail);
    }

    // combined cases

    function testInputDataWithValidFuzzing(uint256 _actionIndex, uint256 _value1, uint256 _value2) public {
        uint256 arrayLength = _actionIndex % 3 + 1; // to ensures length is always between 1 and 3
        ICLTBase.StrategyPayload[] memory strategyDetailArray = new ICLTBase.StrategyPayload[](arrayLength);

        for (uint256 i = 0; i < arrayLength; i++) {
            if (i % 2 == 0) {
                vm.assume(_value1 > 0);
                strategyDetailArray[i].actionName = rebaseModule.REBASE_INACTIVITY();
                strategyDetailArray[i].data = abi.encode(_value1);
            } else if (i % 2 == 1) {
                vm.assume(_value1 > 0 && _value1 < 8_388_608 && _value2 < 8_388_608 && _value2 > 0);
                strategyDetailArray[i].actionName = rebaseModule.PRICE_PREFERENCE();
                strategyDetailArray[i].data = abi.encode(_value1, _value2);
            }
        }

        for (uint256 i = 0; i < arrayLength; i++) {
            assertTrue(rebaseModule.checkInputData(strategyDetailArray[i]));
        }
    }

    function testInputDataWithInvalidFuzzing(uint256 _actionIndex, uint256 _value1, uint256 _value2) public {
        // Define the array length based on fuzzed value
        uint256 arrayLength = _actionIndex % 3 + 1; // Ensures length is always between 1 and 3
        ICLTBase.StrategyPayload[] memory strategyDetailArray = new ICLTBase.StrategyPayload[](arrayLength);

        // Fuzzing different action names with intentionally invalid data
        for (uint256 i = 0; i < arrayLength; i++) {
            if (i % 2 == 0) {
                vm.assume(_value1 <= 0);
                strategyDetailArray[i].actionName = rebaseModule.REBASE_INACTIVITY();
                strategyDetailArray[i].data = abi.encode(0);
            } else if (i % 2 == 1) {
                vm.assume(_value1 <= 0 && _value2 <= 0);
                strategyDetailArray[i].actionName = rebaseModule.PRICE_PREFERENCE();
                strategyDetailArray[i].data = abi.encode(_value1, _value2);
            }
        }

        for (uint256 i = 0; i < arrayLength; i++) {
            _hevm.expectRevert();
            rebaseModule.checkInputData(strategyDetailArray[i]);
        }
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

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyId;

        generateMultipleSwapsWithTime(owner);

        rebaseModule.executeStrategies(strategyIDs);
        (bytes32 strategyID,,,,,) = base.positions(1);
        assertEq(strategyID, strategyId);
    }

    function testArrayWithDuplicatesReverts() public {
        createStrategyAndDepositWithActions(address(this), false, 1, 1);
        createStrategyAndDepositWithActions(address(this), true, 1, 2);
        createStrategyAndDepositWithActions(address(this), true, 2, 3);
        createStrategyAndDepositWithActions(address(this), true, 3, 4);
        createStrategyAndDepositWithActions(address(this), true, 4, 5);

        bytes32[] memory data = new bytes32[](6);
        data[0] = keccak256(abi.encode(address(this), 1));
        data[1] = keccak256(abi.encode(address(this), 2));
        data[2] = keccak256(abi.encode(address(this), 3));
        data[3] = keccak256(abi.encode(address(this), 4));
        data[4] = keccak256(abi.encode(address(this), 5));
        data[5] = data[0];

        bytes memory encodedError = abi.encodeWithSignature("DuplicateStrategyId(bytes32)", data[0]);
        vm.expectRevert(encodedError);
        rebaseModule.checkStrategiesArray(data);
    }

    function testMultipleArray() public {
        createStrategyAndDepositWithActions(address(this), false, 1, 1);
        createStrategyAndDepositWithActions(address(this), true, 1, 2);

        bytes32[] memory data = new bytes32[](6);
        data[0] = keccak256(abi.encode(address(this), 1));
        data[1] = bytes32(0);

        bytes memory encodedError = abi.encodeWithSignature("InvalidStrategyId(bytes32)", data[1]);
        vm.expectRevert(encodedError);
        rebaseModule.checkStrategiesArray(data);
    }

    function testArrays() public {
        createStrategyAndDepositWithActions(address(this), false, 1, 1);
        createStrategyAndDepositWithActions(address(this), true, 1, 2);

        bytes32[] memory data = new bytes32[](2);
        data[0] = keccak256(abi.encode(address(this), 2));
        data[1] = keccak256(abi.encode(""));

        vm.expectRevert();
        rebaseModule.checkStrategiesArray(data);
    }

    function testValidArrays() public {
        createStrategyAndDepositWithActions(address(this), false, 1, 1);
        createStrategyAndDepositWithActions(address(this), true, 1, 2);
        createStrategyAndDepositWithActions(address(this), true, 2, 3);
        createStrategyAndDepositWithActions(address(this), true, 3, 4);
        createStrategyAndDepositWithActions(address(this), true, 4, 5);

        bytes32[] memory data = new bytes32[](5);
        data[0] = keccak256(abi.encode(address(this), 1));
        data[1] = keccak256(abi.encode(address(this), 2));
        data[2] = keccak256(abi.encode(address(this), 3));
        data[3] = keccak256(abi.encode(address(this), 4));
        data[4] = keccak256(abi.encode(address(this), 5));

        rebaseModule.checkStrategiesArray(data);
    }

    function testExecutingStrategyWithEmptyID() public {
        bytes32[] memory strategyIDs = new bytes32[](10);
        vm.expectRevert();
        rebaseModule.executeStrategies(strategyIDs);
    }

    function testExecuteStrategyWithStrategyIDDonotExist() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 43);

        createStrategyAndDeposit(rebaseActions, 1500, owner, 1, 1, true);

        bytes32[] memory strategyIDs = new bytes32[](1);

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

        bytes32[] memory strategyIDs = new bytes32[](1);

        bytes32 strategyID = bytes32(0);

        strategyIDs[0] = strategyID;

        bytes memory encodedError = abi.encodeWithSignature("InvalidStrategyId(bytes32)", strategyID);
        vm.expectRevert(encodedError);
        rebaseModule.executeStrategies(strategyIDs);
    }

    function testGetPreferenceTicks(int24 lpd, int24 upd) public {
        vm.assume(lpd > 0 && lpd < 887_272 && upd < 887_272 && upd > 0);

        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(lpd, upd);

        bytes32 strategyId = createStrategyAndDeposit(rebaseActions, 1500, owner, 1, 1, true);

        (int24 lowerPreferenceTick, int24 upperPreferenceTick) = rebaseModule.getPreferenceTicks(strategyId);
        assertTrue(upperPreferenceTick > lowerPreferenceTick);
    }

    function testEmptyArrayReverts() public {
        bytes32[] memory data = new bytes32[](0);
        bytes memory encodedError = abi.encodeWithSignature("StrategyIdsCannotBeEmpty()");
        vm.expectRevert(encodedError);
        rebaseModule.checkStrategiesArray(data);
    }

    function testArrayWithAllElementsZeroReverts() public {
        bytes32[] memory data = new bytes32[](2);
        data[0] = bytes32(0);
        data[1] = bytes32(0);
        bytes memory encodedError = abi.encodeWithSignature("InvalidStrategyId(bytes32)", data[1]);
        vm.expectRevert(encodedError);
        rebaseModule.checkStrategiesArray(data);
    }

    function testArrayWithAllElementsIdenticalReverts() public {
        bytes32 identicalId = keccak256(abi.encodePacked("strategy"));
        bytes32[] memory data = new bytes32[](3);
        data[0] = identicalId;
        data[1] = identicalId;
        data[2] = identicalId;
        vm.expectRevert();
        rebaseModule.checkStrategiesArray(data);
    }

    // edge
    // 5
    function test_fuzz_ExecuteStrategyAllModesWithOnlyRebaseInactivity(uint256 mode) public {
        vm.assume(mode >= 1 && mode <= 3);
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[0].data = abi.encode(3);

        bytes32 strategyID = createStrategyAndDeposit(rebaseActions, 1500, owner, 1, mode, true);

        bytes32[] memory strategyIDs = new bytes32[](1);

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
        rebaseActions[1].data = abi.encode(2, false);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 1500, owner, 1, 1, true);

        executeSwap(token0, token1, owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);
        (uint256 count,) = abi.decode(actionStatus, (uint256, bool));
        assertEq(count, 1);

        // for mode 2
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(45, 22);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(1);

        bytes32 strategyID2 = createStrategyAndDeposit(rebaseActions, 3000, owner, 2, 2, true);

        executeSwap(token1, token0, owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        strategyIDs[0] = strategyID2;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID2);
        (count,) = abi.decode(actionStatus, (uint256, bool));
        assertEq(count, 1);

        // for mode 3
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(76, 2);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(1);

        bytes32 strategyID3 = createStrategyAndDeposit(rebaseActions, 1700, owner, 3, 3, true);

        executeSwap(token0, token1, owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        strategyIDs[0] = strategyID3;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID3);

        (count,) = abi.decode(actionStatus, (uint256, bool));
        assertEq(count, 1);

        // for mode 3
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(34, 11);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(1);

        bytes32 strategyID4 = createStrategyAndDeposit(rebaseActions, 500, owner, 4, 3, true);

        executeSwap(token1, token0, owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        strategyIDs[0] = strategyID4;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID4);
        (count,) = abi.decode(actionStatus, (uint256, bool));
        assertEq(count, 1);
    }

    function testExecuteStrategyShouldNotRebasePastLimitMode1() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 1500, owner, 1, 1, true);

        executeSwap(token0, token1, owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        executeSwap(token0, token1, owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);

        executeSwap(token0, token1, owner, 500e18, 0, 0);
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

        executeSwap(token1, token0, owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        executeSwap(token1, token0, owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);

        executeSwap(token1, token0, owner, 150e18, 0, 0);

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

        executeSwap(token1, token0, owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        executeSwap(token0, token1, owner, 500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);

        executeSwap(token1, token0, owner, 150e18, 0, 0);

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

        executeSwap(token0, token1, owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        executeSwap(token0, token1, owner, 150e18, 0, 0);

        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);

        executeSwap(token0, token1, owner, 150e18, 0, 0);

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

        executeSwap(token1, token0, owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        executeSwap(token1, token0, owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        rebaseModule.executeStrategies(strategyIDs);

        (,,, actionStatus,,,,,) = base.strategies(strategyID1);

        assertEq(abi.decode(actionStatus, (uint256)), 2);

        executeSwap(token1, token0, owner, 150e18, 0, 0);

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

        executeSwap(token1, token0, owner, 150e18, 0, 0);
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

        executeSwap(token0, token1, owner, 150e18, 0, 0);
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

        executeSwap(token0, token1, owner, 1500e18, 0, 0);
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
            uint256 randomValue1 = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % 1000;

            uint256 randomValue2 =
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i, "second"))) % 1000;

            int24 depositAmount = int24(
                int256(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i, "deposit"))) % 1000 + 1)
            );

            uint256 mode = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i, "last"))) % 3 + 1;

            ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);
            rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
            rebaseActions[0].data = abi.encode(randomValue1, randomValue2);
            rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
            rebaseActions[1].data = abi.encode(mode);

            bytes32 strategyID = createStrategyAndDeposit(rebaseActions, depositAmount, owner, i + 1, mode, true);

            if (mode == 1) {
                executeSwap(token1, token0, owner, 150e18, 0, 0);
            } else if (mode == 2) {
                executeSwap(token0, token1, owner, 150e18, 0, 0);
            } else {
                executeSwap(token0, token1, owner, 150e18, 0, 0);
            }
            strategyIDs[i] = strategyID;
        }

        rebaseModule.executeStrategies(strategyIDs);
    }

    /**
     * Random scenario 1
     * Rebase inactivity 2 and another user comes after 1 rebase
     */
    function testScenario1() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        allowNewUser(users[0], address(this), 10 ether);

        ICLTBase.PositionActions memory positionActions;
        positionActions.mode = 2;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(700, users[0], true, positionActions);

        bytes32 strategyID = getStrategyID(users[0], 1);

        depoit(strategyID, users[0], 10 ether, 10 ether);

        ICLTBase.Account memory accounts;
        ICLTBase.StrategyKey memory key;

        (key,,,,,,,, accounts) = base.strategies(strategyID);
        (uint256 reserve0, uint256 reserve1) = getStrategyReserves(key, accounts.uniswapLiquidity);

        executeSwap(token1, token0, owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        allowNewUser(users[1], address(this), 10 ether);

        assertEq(token0.balanceOf(users[1]), 10 ether);
        assertEq(token1.balanceOf(users[1]), 10 ether);

        depoit(strategyID, users[1], 10 ether, 10 ether);

        uint256 previousBalance0 = accounts.balance0;

        (key,,,,,,,, accounts) = base.strategies(strategyID);
        (reserve0, reserve1) = getStrategyReserves(key, accounts.uniswapLiquidity);

        assertEq(token0.balanceOf(users[1]), 10 ether - (accounts.balance0 - previousBalance0));
        assertEq(token1.balanceOf(users[1]), 0);

        executeSwap(token0, token1, owner, 50e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        assertEq(checkRange(key.tickLower, key.tickUpper), true);

        (, uint256 shares2,,,,) = base.positions(2);

        _hevm.prank(users[1]);
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 2,
                liquidity: shares2,
                recipient: users[1],
                refundAsETH: false,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function testFailScenario2() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        allowNewUser(users[0], address(this), 10 ether);

        ICLTBase.PositionActions memory positionActions;
        positionActions.mode = 2;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        createStrategyActions(700, users[0], false, positionActions);

        bytes32 strategyID = getStrategyID(users[0], 1);

        depoit(strategyID, users[0], 10 ether, 10 ether);

        executeSwap(token1, token0, owner, 150e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID);

        assertEq(abi.decode(actionStatus, (uint256)), 1);

        allowNewUser(users[1], address(this), 100 ether);

        assertEq(token0.balanceOf(users[1]), 100 ether);
        assertEq(token1.balanceOf(users[1]), 100 ether);

        depoit(strategyID, users[1], 10 ether, 10 ether);

        ICLTBase.Account memory accounts;
        ICLTBase.StrategyKey memory key;
        (key,,,,,,,, accounts) = base.strategies(strategyID);

        (, uint256 reserve1) = getStrategyReserves(key, accounts.uniswapLiquidity);
        (, uint256 shares2,,,,) = base.positions(2);

        _hevm.prank(address(base));
        key.pool.burn(key.tickLower, key.tickUpper, 0, "");

        _hevm.prank(address(base));

        assertEq(token0.balanceOf(users[1]), 100 ether - accounts.balance0);
        // precision error of 0.077071791677914138 here
        assertEq(token1.balanceOf(users[1]), 100 ether - (reserve1 * shares2) / accounts.totalShares);

        executeSwap(token0, token1, owner, 50e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        assertEq(checkRange(key.tickLower, key.tickUpper), true);

        (, shares2,,,,) = base.positions(2);

        _hevm.prank(users[1]);
        base.withdraw(
            ICLTBase.WithdrawParams({
                tokenId: 2,
                liquidity: shares2,
                recipient: users[1],
                refundAsETH: false,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    // strategyID should not execute as shares are less than threshold
    function testInvalidDataScenario1() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 43);

        ICLTBase.PositionActions memory positionActions;

        positionActions.mode = 1;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        initStrategy(800);
        base.createStrategy(strategyKey, positionActions, 0, 0, true, false);
        bytes32 strategyID1 = getStrategyID(owner, 1);

        ICLTBase.DepositParams memory depositParams;

        bytes32 strategyID = getStrategyID(owner, 1);

        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 2000;
        depositParams.amount1Desired = 2000;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = owner;

        base.deposit(depositParams);

        executeSwap(token1, token0, owner, 1500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID1);

        int24 ticksLowerBefore = key.tickLower;
        int24 ticksUpperBefore = key.tickUpper;

        rebaseModule.executeStrategies(strategyIDs);

        (key,,,,,,,,) = base.strategies(strategyID1);

        assertEq(ticksLowerBefore, key.tickLower);
        assertEq(ticksUpperBefore, key.tickUpper);
    }

    function testInvalidDataScenario2() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](2);

        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 56);

        rebaseActions[1].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[1].data = abi.encode(2);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 700, owner, 1, 2, true);

        executeSwap(token1, token0, owner, 1500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        (ICLTBase.StrategyKey memory key,,,,,,,,) = base.strategies(strategyID1);

        int24 ticksLowerBefore = key.tickLower;
        int24 ticksUpperBefore = key.tickUpper;

        rebaseModule.executeStrategies(strategyIDs);

        (key,,,,,,,,) = base.strategies(strategyID1);

        assertEq(ticksLowerBefore != key.tickLower, true);
        assertEq(ticksUpperBefore != key.tickUpper, true);
    }

    function testInvalidDataScenario3() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);

        rebaseActions[0].actionName = rebaseModule.REBASE_INACTIVITY();
        rebaseActions[0].data = abi.encode(2);

        bytes32 strategyID1 = createStrategyAndDeposit(rebaseActions, 700, owner, 1, 2, true);

        executeSwap(token1, token0, owner, 1500e18, 0, 0);
        _hevm.warp(block.timestamp + 3600);

        bytes32[] memory strategyIDs = new bytes32[](1);

        strategyIDs[0] = strategyID1;

        rebaseModule.executeStrategies(strategyIDs);

        (,,, bytes memory actionStatus,,,,,) = base.strategies(strategyID1);
        assertEq(actionStatus, "");
    }
}
