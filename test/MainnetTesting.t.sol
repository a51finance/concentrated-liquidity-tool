// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { MainnetFixtures } from "./utils/MainnetFixtures.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { PoolActions } from "../src/libraries/PoolActions.sol";
import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { PositionKey } from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { LiquidityAmounts } from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";

contract MainnetTest is Test, MainnetFixtures {
    address owner;

    function setUp() public {
        owner = 0x6673199BB95a7B742dC7Bd77E8bDA18E27942DD9;
        initBase(owner);
        deal(address(pool.token0()), owner, 100e18);
        deal(address(pool.token1()), owner, 100e18);
    }

    function test_MainnetTest() public {
        console.log(token0.balanceOf(owner));
        console.log(token1.balanceOf(owner));

        (, int24 tick,,,,,) = pool.slot0();

        int24 tickLower = floorTicks(tick - 550, pool.tickSpacing());
        int24 tickUpper = floorTicks(tick + 600, pool.tickSpacing());

        _hevm.prank(owner);
        (bytes32 strategyID, bytes memory data, ICLTBase.PositionActions memory positionActions) =
            createActiveRebalancingAndDeposit(owner, tick, tickLower, tickUpper, 300, 200);

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyID);

        console.log("Balances After Deposit", account.balance0);
        console.log("Balances After Deposit", account.balance1);

        getAllTicks(strategyID, rebaseModule.ACTIVE_REBALANCE(), data, true);

        executeSwap(token1, token0, pool.fee(), owner, 1e18, 0, 0);
        executeSwap(token0, token1, pool.fee(), owner, 1e18, 0, 0);
    }
}
