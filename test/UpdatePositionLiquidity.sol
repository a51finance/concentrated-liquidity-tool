// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { Test } from "forge-std/Test.sol";
import { CLTBase } from "../src/CLTBase.sol";

import { Fixtures } from "./utils/Fixtures.sol";
import { Utilities } from "./utils/Utilities.sol";

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract UpdatePositionLiquidityTest is Test, Fixtures {
    Utilities utils;
    ICLTBase.StrategyKey key;

    event PositionUpdated(uint256 indexed tokenId, uint256 share, uint256 amount0, uint256 amount1);

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
    }

    function test_increaseLiq_succeedCorrectEventParams() public {
        uint256 depositAmount = 1 ether;

        vm.expectEmit(true, true, false, true);
        emit PositionUpdated(1, depositAmount, depositAmount, depositAmount);

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({ tokenId: 1, amount0Desired: depositAmount, amount1Desired: depositAmount })
        );

        vm.expectEmit(true, true, false, true);
        emit PositionUpdated(2, depositAmount, depositAmount, depositAmount);

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({ tokenId: 2, amount0Desired: depositAmount, amount1Desired: depositAmount })
        );
    }

    function test_increaseLiq_succeedsWithCorrectShare() public {
        uint256 depositAmount = 4 ether;

        uint256 liquidityShareBefore;
        uint256 liquidityShareAfter;

        (, liquidityShareBefore,,,,) = base.positions(1);

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({ tokenId: 1, amount0Desired: depositAmount, amount1Desired: depositAmount })
        );

        (, liquidityShareAfter,,,,) = base.positions(1);

        assertEq(liquidityShareAfter, liquidityShareBefore + depositAmount);

        (, liquidityShareBefore,,,,) = base.positions(2);

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({ tokenId: 2, amount0Desired: depositAmount, amount1Desired: depositAmount })
        );

        (, liquidityShareAfter,,,,) = base.positions(2);

        assertEq(liquidityShareAfter, liquidityShareBefore + depositAmount);
    }

    function test_increaseLiq_succeedsAfterExit() public {
        uint256 depositAmount = 4 ether;
        base.toggleOperator(msg.sender);

        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 1),
                shouldMint: false,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: abi.encode(1, true)
            })
        );

        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 2),
                shouldMint: false,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: abi.encode(1, true)
            })
        );

        (,,,,,,,, ICLTBase.Account memory accountStrategy1) = base.strategies(getStrategyID(address(this), 1));

        uint256 balance0Before = accountStrategy1.balance0;
        uint256 balance1Before = accountStrategy1.balance1;

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({ tokenId: 1, amount0Desired: depositAmount, amount1Desired: depositAmount })
        );

        (,,,,,,,, accountStrategy1) = base.strategies(getStrategyID(address(this), 1));

        assertEq(accountStrategy1.balance0, balance0Before + depositAmount);
        assertEq(accountStrategy1.balance1, balance1Before + depositAmount);

        (,,,,,,,, ICLTBase.Account memory accountStrategy2) = base.strategies(getStrategyID(address(this), 2));

        balance0Before = accountStrategy2.balance0;
        balance1Before = accountStrategy2.balance1;

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({ tokenId: 2, amount0Desired: depositAmount, amount1Desired: depositAmount })
        );

        (,,,,,,,, accountStrategy2) = base.strategies(getStrategyID(address(this), 2));

        assertEq(accountStrategy2.balance0, balance0Before + depositAmount);
        assertEq(accountStrategy2.balance1, balance1Before + depositAmount);
    }
}
