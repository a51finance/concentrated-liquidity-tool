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
}
