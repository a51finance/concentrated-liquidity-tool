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
        (ICLTBase.StrategyKey memory key,,,,,,,,,,) = baseContract.strategies(strategyID);

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

        IPreference.StrategyInputData[] memory strategyIDs = new IPreference.StrategyInputData[](1);

        strategyIDs[0].strategyID = strategyId;
        strategyIDs[0].rebaseOptions = "";

        vm.expectRevert();
        rebaseModule.executeStrategies(strategyIDs);
    }

    function testExecuteStrategyWithValidStrategyID() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        bytes32 strategyId = createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 1, 1);

        IPreference.StrategyInputData[] memory strategyIDs = new IPreference.StrategyInputData[](1);

        strategyIDs[0].strategyID = strategyId;
        strategyIDs[0].rebaseOptions = "";

        generateMultipleSwapsWithTime(owner);

        rebaseModule.executeStrategies(strategyIDs);
        (bytes32 strategyID,,,,,) = baseContract.positions(1);
        assertEq(strategyID, strategyId);
    }

    function testExecutingStrategyWithEmptyID() public {
        IPreference.StrategyInputData[] memory strategyIDs = new IPreference.StrategyInputData[](10);
        vm.expectRevert();
        rebaseModule.executeStrategies(strategyIDs);
    }

    function testExecuteStrategyWithStrategyIDDonotExist() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(23, 43);

        createStrategyAndDeposit(rebaseActions, baseContract, poolContract, 1500, owner, 1, 1);

        IPreference.StrategyInputData[] memory strategyIDs = new IPreference.StrategyInputData[](1);

        bytes32 strategyID = keccak256(abi.encode(users[2], 1));

        strategyIDs[0].strategyID = strategyID;
        strategyIDs[0].rebaseOptions = "";

        vm.expectRevert();
        rebaseModule.executeStrategies(strategyIDs);
    }
}
