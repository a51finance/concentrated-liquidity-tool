// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import { Test } from "forge-std/Test.sol";
import { Fixtures } from "./utils/Fixtures.sol";

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { ICLTModules } from "../src/interfaces/ICLTModules.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";

contract ModulesTest is Test, Fixtures {
    function setUp() public {
        deployFreshState();
    }

    function test_modules_revertsIfNotOwnerToUpdateModule() public {
        vm.prank(msg.sender);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        cltModules.setNewModule(keccak256("LIQUIDITY_DISTRIBUTION"), keccak256("PRICE_RANGE"));
    }

    function test_modules_revertsIfNotOwnerToToggleModule() public {
        vm.prank(msg.sender);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        cltModules.toggleModule(keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"));
    }

    function test_modules_revertsIfNotOwnerToUpdateModuleAddress() public {
        vm.prank(msg.sender);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        cltModules.setModuleAddress(keccak256("REBASE_STRATEGY"), address(1445));
    }

    function test_modules_revertsIfInvalidModule() public {
        vm.expectRevert("Invalid Strategy Key");
        cltModules.setNewModule(keccak256("TRADING_STRATEGY"), keccak256("PRICE_RANGE"));
    }

    function test_modules_revertsIfMaxManagementFee() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(1, 3, 0, 3, 0, 0);

        vm.expectRevert("ManagementFeeLimitExceed");
        cltModules.validateModes(actions, 0.6 ether, 0);
    }

    function test_modules_revertsIfMaxPerformanceFee() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(1, 3, 0, 3, 0, 0);

        vm.expectRevert("PerformanceFeeLimitExceed");
        cltModules.validateModes(actions, 0, 0.501 ether);
    }

    function test_modules_revertsIfInvalidBasicMode() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(5, 3, 0, 3, 0, 0);

        vm.expectRevert("InvalidMode");
        cltModules.validateModes(actions, 0, 0);
    }

    function test_modules_revertsIfInvalidRebaseStrategyId() public {
        ICLTBase.StrategyPayload[] memory rebaseStrategyActions = new ICLTBase.StrategyPayload[](1);

        rebaseStrategyActions[0].actionName = keccak256("PRICE_RANGE");
        rebaseStrategyActions[0].data = "";

        ICLTBase.PositionActions memory actions = ICLTBase.PositionActions({
            mode: 1,
            exitStrategy: new ICLTBase.StrategyPayload[](0),
            rebaseStrategy: rebaseStrategyActions,
            liquidityDistribution: new ICLTBase.StrategyPayload[](0)
        });

        vm.expectRevert("InvalidStrategyAction");
        cltModules.validateModes(actions, 0, 0);
    }

    function test_modules_revertsIfInvalidExitStrategyId() public {
        ICLTBase.StrategyPayload[] memory exitStrategyActions = new ICLTBase.StrategyPayload[](1);

        exitStrategyActions[0].actionName = keccak256("SMART_ENTER");
        exitStrategyActions[0].data = "";

        ICLTBase.PositionActions memory actions = ICLTBase.PositionActions({
            mode: 1,
            exitStrategy: exitStrategyActions,
            rebaseStrategy: new ICLTBase.StrategyPayload[](0),
            liquidityDistribution: new ICLTBase.StrategyPayload[](0)
        });

        vm.expectRevert("InvalidStrategyAction");
        cltModules.validateModes(actions, 0, 0);
    }

    function test_modules_revertsIfInvalidLiquidityStrategyId() public {
        ICLTBase.StrategyPayload[] memory liquidityStrategyActions = new ICLTBase.StrategyPayload[](1);

        liquidityStrategyActions[0].actionName = keccak256("REBASE_INACTIVITY");
        liquidityStrategyActions[0].data = "";

        ICLTBase.PositionActions memory actions = ICLTBase.PositionActions({
            mode: 1,
            exitStrategy: new ICLTBase.StrategyPayload[](0),
            rebaseStrategy: new ICLTBase.StrategyPayload[](0),
            liquidityDistribution: liquidityStrategyActions
        });

        vm.expectRevert("InvalidStrategyAction");
        cltModules.validateModes(actions, 0, 0);
    }

    function test_modules_revertsIfInvalidRebaseStrategyInput1() public {
        ICLTBase.StrategyPayload[] memory rebaseStrategyActions = new ICLTBase.StrategyPayload[](1);

        rebaseStrategyActions[0].actionName = keccak256("REBASE_INACTIVITY");
        rebaseStrategyActions[0].data = abi.encode(0);

        ICLTBase.PositionActions memory actions = ICLTBase.PositionActions({
            mode: 1,
            exitStrategy: new ICLTBase.StrategyPayload[](0),
            rebaseStrategy: rebaseStrategyActions,
            liquidityDistribution: new ICLTBase.StrategyPayload[](0)
        });

        vm.expectRevert();
        cltModules.validateModes(actions, 0, 0);
    }

    function test_modules_revertsIfInvalidRebaseStrategyInput2() public {
        ICLTBase.StrategyPayload[] memory rebaseStrategyActions = new ICLTBase.StrategyPayload[](1);

        rebaseStrategyActions[0].actionName = keccak256("PRICE_PREFERENCE");
        rebaseStrategyActions[0].data = abi.encode(0, 2000);

        ICLTBase.PositionActions memory actions = ICLTBase.PositionActions({
            mode: 1,
            exitStrategy: new ICLTBase.StrategyPayload[](0),
            rebaseStrategy: rebaseStrategyActions,
            liquidityDistribution: new ICLTBase.StrategyPayload[](0)
        });

        vm.expectRevert("InvalidPricePreferenceDifference");
        cltModules.validateModes(actions, 0, 0);
    }

    function test_modules_revertsIfInvalidExitStrategyInput() public {
        cltModules.setModuleAddress(keccak256("EXIT_STRATEGY"), address(rebaseModule));

        ICLTBase.StrategyPayload[] memory exitStrategyActions = new ICLTBase.StrategyPayload[](1);

        exitStrategyActions[0].actionName = keccak256("SMART_EXIT");
        exitStrategyActions[0].data = ""; // this mode is not available so we can't test inputs

        ICLTBase.PositionActions memory actions = ICLTBase.PositionActions({
            mode: 1,
            exitStrategy: exitStrategyActions,
            rebaseStrategy: new ICLTBase.StrategyPayload[](0),
            liquidityDistribution: new ICLTBase.StrategyPayload[](0)
        });

        vm.expectRevert();
        cltModules.validateModes(actions, 0, 0);
    }

    function test_modules_revertsIfInvalidLiquidityStrategyInput() public {
        cltModules.setModuleAddress(keccak256("LIQUIDITY_DISTRIBUTION"), address(rebaseModule));

        ICLTBase.StrategyPayload[] memory liquidityStrategyActions = new ICLTBase.StrategyPayload[](1);

        liquidityStrategyActions[0].actionName = keccak256("PRICE_RANGE");
        liquidityStrategyActions[0].data = ""; // this mode is not available so we can't test inputs

        ICLTBase.PositionActions memory actions = ICLTBase.PositionActions({
            mode: 1,
            exitStrategy: new ICLTBase.StrategyPayload[](0),
            rebaseStrategy: new ICLTBase.StrategyPayload[](0),
            liquidityDistribution: liquidityStrategyActions
        });

        vm.expectRevert();
        cltModules.validateModes(actions, 0, 0);
    }

    function test_modules_shouldToggleModule() public {
        cltModules.toggleModule(keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE"));

        assert(!cltModules.modulesActions(keccak256("REBASE_STRATEGY"), keccak256("PRICE_PREFERENCE")));
    }
}
