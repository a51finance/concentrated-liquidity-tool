// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";

import { CLTBase } from "../src/CLTBase.sol";
import { Fixtures } from "./utils/Fixtures.sol";
import { Utilities } from "./utils/Utilities.sol";

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "forge-std/console.sol";

contract CLTShiftLiquidityTest is Test, Fixtures {
    Utilities utils;
    ICLTBase.StrategyKey key;

    event LiquidityShifted(bytes32 indexed strategyId, bool isLiquidityMinted, bool zeroForOne, int256 swapAmount);

    function setUp() public {
        initManagerRoutersAndPoolsWithLiq();
        utils = new Utilities();

        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -100, tickUpper: 100 });
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        // compounding strategy
        base.createStrategy(key, actions, 0, 0, true, false);
        // non compounding strategy
        base.createStrategy(key, actions, 0, 0, false, false);

        token0.approve(address(base), UINT256_MAX);
        token1.approve(address(base), UINT256_MAX);

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 1),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 2),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

        base.toggleOperator(msg.sender);
    }

    function test_shiftLiquidity_revertsIfNotWhitelistAccount() public {
        vm.prank(address(this));
        vm.expectRevert();
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 1),
                shouldMint: true,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: ""
            })
        );
    }

    function test_shiftLiquidity_protocolShouldReceiveFee() public {
        bytes32 strategyId = getStrategyID(address(this), 1);

        feeHandler.setPublicFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 100_000_000_000_000_000, // 10% protocol fee
                strategyCreationFee: 0,
                protcolFeeOnManagement: 0,
                protcolFeeOnPerformance: 0
            })
        );

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyId);
        (uint256 reserves0, uint256 reserves1) = getStrategyReserves(key, account.uniswapLiquidity);

        vm.prank(address(this));
        base.transferOwnership(msg.sender);

        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 1),
                shouldMint: true,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: ""
            })
        );

        (,,,,,,,, account) = base.strategies(strategyId);
        (uint256 newReserves0, uint256 newReserves1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(newReserves0, reserves0 - 1 - (reserves0 * 10) / 100);
        assertEq(newReserves1, reserves1 - 1 - (reserves1 * 10) / 100);

        assertEq(token0.balanceOf(msg.sender), (reserves0 * 10) / 100);
        assertEq(token1.balanceOf(msg.sender), (reserves1 * 10) / 100);
    }

    function test_shiftLiquidity_() public { }
}
