// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { Fixtures } from "./utils/Fixtures.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";

import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";
import { IAlgebraPool } from "@cryptoalgebra/core/contracts/interfaces/IAlgebraPool.sol";

import "forge-std/console.sol";

contract StrategyTest is Test, Fixtures {
    ICLTBase.StrategyKey key;

    event StrategyCreated(bytes32 indexed strategyId);

    function setUp() public {
        deployFreshState();

        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -100, tickUpper: 100 });
    }

    /// forge test -vv --match-test test_strategy_succeedsWithValidInputsForInactivity
    function test_strategy_succeedsWithValidInputsForInactivity(uint256 mode, uint256 inactivityCounts) public {
        vm.assume(mode > 0 && mode < 4);
        vm.assume(inactivityCounts > 0);

        ICLTBase.PositionActions memory actions = createStrategyActions(mode, 3, 0, inactivityCounts, 0, 0);

        bytes32 strategyId = getStrategyID(address(this), 1);

        vm.expectEmit(true, false, false, false);
        emit StrategyCreated(strategyId);
        base.createStrategy(key, actions, 0, 0, true, false);

        (ICLTBase.StrategyKey memory keyAdded, address owner, bytes memory actionsAdded,, bool isCompound,,,,) =
            base.strategies(strategyId);

        assertEq(isCompound, true);
        assertEq(abi.encode(actions), actionsAdded);
        assertEq(key.tickLower, keyAdded.tickLower);
        assertEq(owner, address(this));
    }

    function test_strategy_succeedsWithValidInputsForPreference() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(1, 1, 0, 0, 723, 482);

        base.createStrategy(key, actions, 0, 0, true, false);

        bytes32 strategyId = getStrategyID(address(this), 1);

        (,, bytes memory actionsAdded,,,,,,) = base.strategies(strategyId);

        assertEq(abi.encode(actions), actionsAdded);
    }

    function test_strategy_revertsIfNotStrategyOwner() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(1, 3, 0, 3, 0, 0);
        base.createStrategy(key, actions, 0, 0, true, false);

        vm.prank(msg.sender);
        vm.expectRevert("InvalidCaller");
        base.updateStrategyBase(getStrategyID(address(this), 1), address(1445), 0.2 ether, 0.3 ether, actions);
    }

    function test_strategy_shouldPayProtocolFee() public {
        feeHandler.setPublicFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0,
                strategyCreationFee: 0.4 ether, // 0.4 ETH strategy creation fee
                protcolFeeOnManagement: 0,
                protcolFeeOnPerformance: 0
            })
        );

        base.transferOwnership(address(1445));

        ICLTBase.PositionActions memory actions = createStrategyActions(1, 3, 0, 3, 0, 0);

        base.createStrategy{ value: 0.4 ether }(key, actions, 0, 0, true, false);

        assertEq(address(1445).balance, 0.4 ether);
    }

    function test_strategy_shouldUpdateStrategy() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(1, 3, 0, 3, 0, 0);
        base.createStrategy(key, actions, 0, 0, true, false);

        bytes32 strategyId = getStrategyID(address(this), 1);

        actions = createStrategyActions(3, 1, 0, 0, 100, 200);

        base.updateStrategyBase(strategyId, address(1445), 0.2 ether, 0.3 ether, actions);

        (, address owner, bytes memory actionsAdded,,,, uint256 managementFee, uint256 performanceFee,) =
            base.strategies(strategyId);

        assertEq(owner, address(1445));
        assertEq(actionsAdded, abi.encode(actions));
        assertEq(managementFee, 0.2 ether);
        assertEq(performanceFee, 0.3 ether);
    }

    function test_strategy_succeedsWithValidInputsForTime() public { }
}
