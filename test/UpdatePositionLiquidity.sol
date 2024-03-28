// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

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

    function test_increaseLiq_revertsOnlyOwnerInPrivateStrategy() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);
        base.createStrategy(key, actions, 0, 0, true, true);

        bytes32 strategyID = getStrategyID(address(this), 3);
        uint256 depositAmount = 3 ether;

        ICLTBase.DepositParams memory params = ICLTBase.DepositParams({
            strategyId: strategyID,
            amount0Desired: depositAmount,
            amount1Desired: depositAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender
        });

        base.deposit(params);

        vm.prank(msg.sender);
        vm.expectRevert();
        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({
                tokenId: 3,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function test_increaseLiq_succeedCorrectEventParams() public {
        uint256 depositAmount = 1 ether;

        vm.expectEmit(true, true, false, true);
        emit PositionUpdated(1, depositAmount, depositAmount, depositAmount);

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({
                tokenId: 1,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        vm.expectEmit(true, true, false, true);
        emit PositionUpdated(2, depositAmount, depositAmount, depositAmount);

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({
                tokenId: 2,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function test_increaseLiq_succeedsWithCorrectShare() public {
        uint256 depositAmount = 4 ether;

        uint256 liquidityShareBefore;
        uint256 liquidityShareAfter;

        (, liquidityShareBefore,,,,) = base.positions(1);

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({
                tokenId: 1,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        (, liquidityShareAfter,,,,) = base.positions(1);

        assertEq(liquidityShareAfter, liquidityShareBefore + depositAmount);

        (, liquidityShareBefore,,,,) = base.positions(2);

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({
                tokenId: 2,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0
            })
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
                moduleStatus: abi.encode(1, true),
                sqrtPriceLimitX96: 0
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
                moduleStatus: abi.encode(1, true),
                sqrtPriceLimitX96: 0
            })
        );

        (,,,,,,,, ICLTBase.Account memory accountStrategy1) = base.strategies(getStrategyID(address(this), 1));

        uint256 balance0Before = accountStrategy1.balance0;
        uint256 balance1Before = accountStrategy1.balance1;

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({
                tokenId: 1,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        (,,,,,,,, accountStrategy1) = base.strategies(getStrategyID(address(this), 1));

        assertEq(accountStrategy1.balance0, balance0Before + depositAmount);
        assertEq(accountStrategy1.balance1, balance1Before + depositAmount);

        (,,,,,,,, ICLTBase.Account memory accountStrategy2) = base.strategies(getStrategyID(address(this), 2));

        balance0Before = accountStrategy2.balance0;
        balance1Before = accountStrategy2.balance1;

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({
                tokenId: 2,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        (,,,,,,,, accountStrategy2) = base.strategies(getStrategyID(address(this), 2));

        assertEq(accountStrategy2.balance0, balance0Before + depositAmount);
        assertEq(accountStrategy2.balance1, balance1Before + depositAmount);
    }

    function test_increaseLiq_shouldUpdateFeeGrowth() public {
        uint256 depositAmount = 5 ether;
        bytes32 strategyId = getStrategyID(address(this), 2);

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 1e30,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        vm.prank(address(base));
        pool.burn(key.tickLower, key.tickUpper, 0);
        (,,, uint256 totalFee0, uint256 totalFee1) =
            key.pool.positions(keccak256(abi.encodePacked(address(base), key.tickLower, key.tickUpper)));

        base.getStrategyReserves(strategyId);
        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(strategyId);

        base.updatePositionLiquidity(
            ICLTBase.UpdatePositionParams({
                tokenId: 2,
                amount0Desired: depositAmount,
                amount1Desired: depositAmount,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        (
            ,
            ,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = base.positions(2);

        assertEq(feeGrowthInside0LastX128, account.feeGrowthInside0LastX128);
        assertEq(feeGrowthInside1LastX128, account.feeGrowthInside1LastX128);

        assertEq(tokensOwed0, totalFee0 / 2 - 2);
        assertEq(tokensOwed1, totalFee1 / 2 - 2);
    }
}
