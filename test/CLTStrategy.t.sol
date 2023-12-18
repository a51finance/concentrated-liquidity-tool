// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { Fixtures } from "./utils/Fixtures.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract CLTStrategyTest is Test, Fixtures {
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

    function test_strategy_succeedsWithValidInputsForPreference() public { }

    function test_strategy_succeedsWithValidInputsForTime() public { }
}
