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
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";

import { ModeTicksCalculation } from "../src/base/ModeTicksCalculation.sol";

import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "forge-std/console.sol";

contract ShiftLiquidityTest is Test, Fixtures {
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

    function test_shiftLiquidity_shouldRevertInvalidState() public {
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

        (, int24 tick,,,,,) = pool.slot0();
        int24 tickSpacing = key.pool.tickSpacing();

        tick = utils.floorTicks(tick, tickSpacing);

        ICLTBase.StrategyKey memory newKey =
            ICLTBase.StrategyKey({ pool: pool, tickLower: tick - tickSpacing * 10, tickUpper: tick + tickSpacing * 10 });

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(getStrategyID(address(this), 1));
        (uint256 reserves0, uint256 reserves1) = getStrategyReserves(key, account.uniswapLiquidity);

        // invalid state will be stored here because we are trying to add in range liquidity with only 1 asset
        vm.prank(msg.sender);
        vm.expectRevert();
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: newKey,
                strategyId: getStrategyID(address(this), 1),
                shouldMint: true,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: "",
                sqrtPriceLimitX96: 0
            })
        );
    }

    function test_shiftLiquidity_revertsIfNotWhitelistAccount() public {
        assert(base.isOperator(msg.sender));

        vm.prank(address(this));
        vm.expectRevert();
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 1),
                shouldMint: true,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: "",
                sqrtPriceLimitX96: 0
            })
        );
    }

    function test_shiftLiquidity_revertsIfShiftingNotNeeded() public {
        bytes32[] memory strategyIDs = new bytes32[](2);
        strategyIDs[0] = getStrategyID(address(this), 1);
        strategyIDs[1] = getStrategyID(address(this), 2);

        // update pool cardinality
        pool.increaseObservationCardinalityNext(80);
        vm.warp(block.timestamp + 1 days);

        base.toggleOperator(address(modes));
        vm.expectRevert(ModeTicksCalculation.LiquidityShiftNotNeeded.selector);
        modes.ShiftBase(strategyIDs);
    }

    function test_shiftLiquidity_succeedCorrectEventParams() public {
        vm.expectEmit(true, true, false, true);
        emit LiquidityShifted(getStrategyID(address(this), 1), true, false, 0);

        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 1),
                shouldMint: true,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: "",
                sqrtPriceLimitX96: 0
            })
        );

        vm.expectEmit(true, true, false, true);
        emit LiquidityShifted(getStrategyID(address(this), 2), false, false, 0);

        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 2),
                shouldMint: false,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: "",
                sqrtPriceLimitX96: 0
            })
        );
    }

    function test_shiftLiquidity_poc1() public {
        base.toggleOperator(address(rebaseModule));

        key = ICLTBase.StrategyKey({ pool: pool, tickLower: -400, tickUpper: 400 });
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        // create new strategy
        base.createStrategy(key, actions, 0, 0, true, false);

        // deposit liquidity on new strategy
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 3),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

        // HODL liquidity
        rebaseModule.executeStrategy(
            IRebaseStrategy.ExectuteStrategyParams({
                pool: key.pool,
                strategyID: getStrategyID(address(this), 3),
                tickLower: key.tickLower,
                tickUpper: key.tickUpper,
                shouldMint: false,
                zeroForOne: false,
                swapAmount: 0,
                sqrtPriceLimitX96: 0
            })
        );

        // change anything in strategy
        base.updateStrategyBase(getStrategyID(address(this), 3), address(this), 0.4 ether, 0.1 ether, actions);

        // re mint liquidity on dex
        rebaseModule.executeStrategy(
            IRebaseStrategy.ExectuteStrategyParams({
                pool: key.pool,
                strategyID: getStrategyID(address(this), 3),
                tickLower: key.tickLower,
                tickUpper: key.tickUpper,
                shouldMint: true,
                zeroForOne: false,
                swapAmount: 100,
                sqrtPriceLimitX96: TickMath.MAX_SQRT_RATIO - 1
            })
        );
    }

    function test_shiftLiquidity_protocolShouldReceiveFee() public {
        bytes32 strategyId = getStrategyID(address(this), 1);

        feeHandler.setPublicFeeRegistry(
            IGovernanceFeeHandler.ProtocolFeeRegistry({
                lpAutomationFee: 0.1 ether, // 10% protocol fee
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
                moduleStatus: "",
                sqrtPriceLimitX96: 0
            })
        );

        (,,,,,,,, account) = base.strategies(strategyId);
        (uint256 newReserves0, uint256 newReserves1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(newReserves0, reserves0 - 1 - (reserves0 * 10) / 100);
        assertEq(newReserves1, reserves1 - 1 - (reserves1 * 10) / 100);

        assertEq(token0.balanceOf(msg.sender), (reserves0 * 10) / 100);
        assertEq(token1.balanceOf(msg.sender), (reserves1 * 10) / 100);
    }

    function test_shiftLiquidity_succeedShiftLeft() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(1, 3, 0, 3, 0, 0);

        // compounding strategy
        base.createStrategy(key, actions, 0, 0, true, false);
        // non compounding strategy
        base.createStrategy(key, actions, 0, 0, false, false);

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 3),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 4),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

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

        (, int24 tick,,,,,) = pool.slot0();
        int24 tickSpacing = key.pool.tickSpacing();

        tick = utils.floorTicks(tick, tickSpacing);

        bytes32[] memory strategyIDs = new bytes32[](2);
        strategyIDs[0] = getStrategyID(address(this), 3);
        strategyIDs[1] = getStrategyID(address(this), 4);

        // update pool cardinality
        pool.increaseObservationCardinalityNext(80);
        vm.warp(block.timestamp + 1 days);

        base.toggleOperator(address(modes));
        modes.ShiftBase(strategyIDs);

        (ICLTBase.StrategyKey memory newKey,,,,,,,,) = base.strategies(getStrategyID(address(this), 3));

        assertEq(newKey.tickLower, tick + tickSpacing);
        assertEq(newKey.tickUpper, newKey.tickLower + 200);

        (newKey,,,,,,,,) = base.strategies(getStrategyID(address(this), 4));

        assertEq(newKey.tickLower, tick + tickSpacing);
        assertEq(newKey.tickUpper, newKey.tickLower + 200);
    }

    function test_shiftLiquidity_succeedShiftRight() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        // compounding strategy
        base.createStrategy(key, actions, 0, 0, true, false);
        // non compounding strategy
        base.createStrategy(key, actions, 0, 0, false, false);

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 3),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 4),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
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

        (, int24 tick,,,,,) = pool.slot0();
        int24 tickSpacing = key.pool.tickSpacing();

        tick = utils.floorTicks(tick, tickSpacing);

        bytes32[] memory strategyIDs = new bytes32[](2);
        strategyIDs[0] = getStrategyID(address(this), 3);
        strategyIDs[1] = getStrategyID(address(this), 4);

        // update pool cardinality
        pool.increaseObservationCardinalityNext(80);
        vm.warp(block.timestamp + 1 days);

        base.toggleOperator(address(modes));
        modes.ShiftBase(strategyIDs);

        (ICLTBase.StrategyKey memory newKey,,,,,,,,) = base.strategies(getStrategyID(address(this), 3));

        assertEq(newKey.tickUpper, tick - tickSpacing);
        assertEq(newKey.tickLower, newKey.tickUpper - 200);

        (newKey,,,,,,,,) = base.strategies(getStrategyID(address(this), 4));

        assertEq(newKey.tickUpper, tick - tickSpacing);
        assertEq(newKey.tickLower, newKey.tickUpper - 200);
    }

    function test_shiftLiquidity_mintLiquidityAfterExit() public {
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

        // snapshot total reserves
        (uint128 liquidity, uint256 fee0, uint256 fee1) = base.getStrategyReserves(getStrategyID(address(this), 1));
        (uint256 reserves0, uint256 reserves1) = getStrategyReserves(key, liquidity);

        // check compounding strategy balances
        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 1),
                shouldMint: false,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: "",
                sqrtPriceLimitX96: 0
            })
        );

        (,,,,,,,, ICLTBase.Account memory account) = base.strategies(getStrategyID(address(this), 1));

        assertEq(account.balance0, reserves0 + fee0);
        assertEq(account.balance1, reserves1 + fee1);

        assertEq(account.uniswapLiquidity, 0);

        uint256 hodlBalance0Strategy1 = account.balance0;
        uint256 hodlBalance1Strategy1 = account.balance1;

        // check non-compounding strategy balances
        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 2),
                shouldMint: false,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: "",
                sqrtPriceLimitX96: 0
            })
        );

        (,,,,,,,, account) = base.strategies(getStrategyID(address(this), 2));

        assertEq(account.balance0, reserves0);
        assertEq(account.balance1, reserves1);

        assertEq(account.fee0, fee0);
        assertEq(account.fee1, fee1);

        assertEq(account.uniswapLiquidity, 0);

        uint256 hodlBalance0Strategy2 = account.balance0;
        uint256 hodlBalance1Strategy2 = account.balance1;

        // mint liquidity on dex after HODL { strategy 1 }
        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 1),
                shouldMint: true,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: "",
                sqrtPriceLimitX96: 0
            })
        );

        (,,,,,,,, account) = base.strategies(getStrategyID(address(this), 1));
        (reserves0, reserves1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserves0, hodlBalance0Strategy1 - account.balance0 - 1);
        assertEq(reserves1, hodlBalance1Strategy1 - account.balance1 - 1);

        // mint liquidity on dex after HODL { strategy 2 }
        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 2),
                shouldMint: true,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: "",
                sqrtPriceLimitX96: 0
            })
        );

        (,,,,,,,, account) = base.strategies(getStrategyID(address(this), 2));
        (reserves0, reserves1) = getStrategyReserves(key, account.uniswapLiquidity);

        assertEq(reserves0, hodlBalance0Strategy2 - account.balance0 - 1);
        assertEq(reserves1, hodlBalance1Strategy2 - account.balance1 - 1);

        //  previous fee should remain same for non compound after mint
        assertEq(account.fee0, fee0);
        assertEq(account.fee1, fee1);
    }

    function test_shiftLiquidity_shouldNotEarnFeeAfterExit() public {
        ICLTBase.PositionActions memory actions = createStrategyActions(2, 3, 0, 3, 0, 0);

        // create compounding strategy again
        base.createStrategy(key, actions, 0, 0, true, false);
        // create non compounding strategy again
        base.createStrategy(key, actions, 0, 0, false, false);

        vm.startPrank(address(this));
        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 3),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );

        base.deposit(
            ICLTBase.DepositParams({
                strategyId: getStrategyID(address(this), 4),
                amount0Desired: 4 ether,
                amount1Desired: 4 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this)
            })
        );
        vm.stopPrank();

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 20e30,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 20e30,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        (, uint256 fee0Strategy1Before, uint256 fee1Strategy1Before) =
            base.getStrategyReserves(getStrategyID(address(this), 1));

        (, uint256 fee0Strategy2Before, uint256 fee1Strategy2Before) =
            base.getStrategyReserves(getStrategyID(address(this), 2));

        (, uint256 fee0Strategy4Before, uint256 fee1Strategy4Before) =
            base.getStrategyReserves(getStrategyID(address(this), 4));

        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 3),
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
                strategyId: getStrategyID(address(this), 4),
                shouldMint: false,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: abi.encode(1, true),
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
                amountIn: 20e30,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp + 1 days,
                amountIn: 20e30,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        uint256 fee0;
        uint256 fee1;

        vm.prank(address(base));
        pool.burn(key.tickLower, key.tickUpper, 0);
        (,,, uint256 totalFee0, uint256 totalFee1) =
            key.pool.positions(keccak256(abi.encodePacked(address(base), key.tickLower, key.tickUpper)));

        (, fee0, fee1) = base.getStrategyReserves(getStrategyID(address(this), 1));

        // non exit strategies should earn latest fee share
        assertEq(fee0, fee0Strategy1Before + (totalFee0 / 2) - 1);
        assertEq(fee1, fee1Strategy1Before + (totalFee1 / 2) - 1);

        (, fee0, fee1) = base.getStrategyReserves(getStrategyID(address(this), 2));

        assertEq(fee0, fee0Strategy2Before + (totalFee0 / 2) - 1);
        assertEq(fee1, fee1Strategy2Before + (totalFee1 / 2) - 1);

        // exit strategies should not earn latest fee share
        (, fee0, fee1) = base.getStrategyReserves(getStrategyID(address(this), 3));

        assertEq(fee0, 0);
        assertEq(fee1, 0);

        (, fee0, fee1) = base.getStrategyReserves(getStrategyID(address(this), 4));

        assertEq(fee0, fee0Strategy4Before);
        assertEq(fee1, fee1Strategy4Before);

        /// fee should start earning again if added on dex
    }

    function test_shiftLiquidity_shouldUpdateFeeGrowthForTicks() public {
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

        (, int24 tick,,,,,) = pool.slot0();
        int24 tickSpacing = key.pool.tickSpacing();

        tick = utils.floorTicks(tick, tickSpacing);

        ICLTBase.StrategyKey memory newKey =
            ICLTBase.StrategyKey({ pool: pool, tickLower: tick - tickSpacing - 200, tickUpper: tick - tickSpacing });

        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: newKey,
                strategyId: getStrategyID(address(this), 1),
                shouldMint: true,
                zeroForOne: false,
                swapAmount: 0,
                moduleStatus: "",
                sqrtPriceLimitX96: 0
            })
        );

        (,,,,,,,, ICLTBase.Account memory accountStrategy1) = base.strategies(getStrategyID(address(this), 1));

        // fee growth of new ticks will be zero
        assertEq(accountStrategy1.feeGrowthOutside0LastX128, 0);
        assertEq(accountStrategy1.feeGrowthOutside1LastX128, 0);

        (, uint256 fee0Strategy2Before, uint256 fee1Strategy2Before) =
            base.getStrategyReserves(getStrategyID(address(this), 2));

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
        pool.burn(newKey.tickLower, newKey.tickUpper, 0);
        (,,, uint256 totalFee0, uint256 totalFee1) =
            pool.positions(keccak256(abi.encodePacked(address(base), newKey.tickLower, newKey.tickUpper)));

        (, uint256 fee0, uint256 fee1) = base.getStrategyReserves(getStrategyID(address(this), 1));

        assertEq(fee0, totalFee0 - 1);
        assertEq(fee1, totalFee1 - 1);

        vm.prank(address(base));
        pool.burn(key.tickLower, key.tickUpper, 0);
        (,,, totalFee0, totalFee1) =
            pool.positions(keccak256(abi.encodePacked(address(base), key.tickLower, key.tickUpper)));

        (, fee0, fee1) = base.getStrategyReserves(getStrategyID(address(this), 2));
        (,,,,,,,, ICLTBase.Account memory accountStrategy2) = base.strategies(getStrategyID(address(this), 2));

        assertEq(fee0, totalFee0 + fee0Strategy2Before - 1);
        assertEq(fee1, totalFee1 + fee1Strategy2Before - 1);

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

        base.getStrategyReserves(getStrategyID(address(this), 2));

        (,,,,,,,, accountStrategy1) = base.strategies(getStrategyID(address(this), 1));
        (,,,,,,,, accountStrategy2) = base.strategies(getStrategyID(address(this), 2));

        vm.prank(msg.sender);
        base.shiftLiquidity(
            ICLTBase.ShiftLiquidityParams({
                key: key,
                strategyId: getStrategyID(address(this), 1),
                shouldMint: true,
                zeroForOne: false,
                swapAmount: int256(accountStrategy1.balance1 / 2),
                moduleStatus: "",
                sqrtPriceLimitX96: 0
            })
        );

        (,,,,,,,, accountStrategy1) = base.strategies(getStrategyID(address(this), 1));

        assertEq(accountStrategy1.feeGrowthOutside0LastX128, accountStrategy2.feeGrowthOutside0LastX128);
        assertEq(accountStrategy1.feeGrowthOutside1LastX128, accountStrategy2.feeGrowthOutside1LastX128);
    }
}
