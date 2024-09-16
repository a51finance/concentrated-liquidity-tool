// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Constants } from "../libraries/Constants.sol";
import { ICLTBase } from "../interfaces/ICLTBase.sol";
import { IGovernanceFeeHandler } from "../interfaces/IGovernanceFeeHandler.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { SqrtPriceMath } from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { LiquidityAmounts } from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

/// @title  ModeTicksCalculation
/// @notice Provides functions for computing ticks for basic modes of strategy
abstract contract ActiveTicksCalculation {
    struct Info {
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0;
        uint256 amount1;
        uint128 liquidity;
        int24 tickLower;
        int24 tickUpper;
    }

    /// @notice Computes new tick lower and upper for the individual strategy downside or upside
    /// @dev it will trail the strategy position closer to the cuurent tick
    /// @param key A51 strategy key details
    /// @return tickLower The lower tick of the range
    /// @return tickUpper The upper tick of the range
    function shiftActive(ICLTBase.StrategyKey memory key) internal view returns (int24, int24) {
        int24 tickSpacing = key.pool.tickSpacing();

        (, int24 currentTick,,,,,) = key.pool.slot0();

        int24 positionWidth = getActivePositionWidth(key.tickLower, key.tickUpper);

        int24 tickLower = floorTickActive(currentTick - (positionWidth / 2), tickSpacing);
        int24 tickUpper = floorTickActive(currentTick + (positionWidth / 2), tickSpacing);

        return (tickLower, tickUpper);
    }

    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`
    /// @param tick The current tick of pool
    /// @param tickSpacing The tick spacing of pool
    /// @return floor value of tick
    function floorTickActive(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    /// @notice Returns the number of ticks between lower & upper tick
    /// @param tickLower The lower tick of strategy
    /// @param tickUpper The upper tick of strategy
    /// @return width The total count of ticks
    function getActivePositionWidth(int24 tickLower, int24 tickUpper) internal pure returns (int24 width) {
        width = tickUpper - tickLower;
    }

    /// @param isPrivate Bool weather strategy is open for all users or not
    /// @param amount0 The amount of token0 from which the strategist fee will deduct
    /// @param amount1 The amount of token1 from which the strategist fee will deduct
    /// @param feeHandler Address of governance fee handler contract.
    function getProtocolFeeses(
        bool isPrivate,
        uint256 amount0,
        uint256 amount1,
        address feeHandler
    )
        internal
        view
        returns (uint256 fee0, uint256 fee1)
    {
        (uint256 percentage,,,) = IGovernanceFeeHandler(feeHandler).getGovernanceFee(isPrivate);

        if (percentage > 0) {
            if (amount0 > 0) {
                fee0 = (amount0 * percentage) / Constants.WAD;
            }

            if (amount1 > 0) {
                fee1 = (amount1 * percentage) / Constants.WAD;
            }
        }
    }

    /// @dev Gets ticks with proportion equivalent to desired amount
    /// @param amount0Desired The desired amount of token0
    /// @param amount1Desired The desired amount of token1
    function getPositionTicks(
        ICLTBase.StrategyKey memory key,
        uint256 amount0Desired,
        uint256 amount1Desired
    )
        internal
        view
        returns (int24 tickLower, int24 tickUpper)
    {
        Info memory cache = Info(amount0Desired, amount1Desired, 0, 0, 0, key.tickLower, key.tickUpper);
        // IUniswapV3Pool pool = IUniswapV3Pool(key.pool);
        // Get current price and tick from the pool
        (uint160 sqrtPriceX96,,,,,,) = key.pool.slot0();
        //Calc amounts of token0 and token1 that can be stored in base range
        (cache.amount0, cache.amount1) =
            getAmountsForTicks(key.pool, cache.amount0Desired, cache.amount1Desired, cache.tickLower, cache.tickUpper);
        // //Liquidity that can be stored in base range
        cache.liquidity =
            getLiquidityForAmounts(key.pool, cache.amount0, cache.amount1, cache.tickLower, cache.tickUpper);

        // //Get imbalanced token
        bool zeroGreaterOne = amountsDirection(cache.amount0Desired, cache.amount1Desired, cache.amount0, cache.amount1);

        //Calc new tick(upper or lower) for imbalanced token
        if (zeroGreaterOne) {
            uint160 nextSqrtPrice0 = SqrtPriceMath.getNextSqrtPriceFromAmount0RoundingUp(
                sqrtPriceX96, cache.liquidity, cache.amount0Desired, false
            );
            cache.tickUpper = floor(TickMath.getTickAtSqrtRatio(nextSqrtPrice0), key.pool.tickSpacing());
        } else {
            uint160 nextSqrtPrice1 = SqrtPriceMath.getNextSqrtPriceFromAmount1RoundingDown(
                sqrtPriceX96, cache.liquidity, cache.amount1Desired, false
            );
            cache.tickLower = floor(TickMath.getTickAtSqrtRatio(nextSqrtPrice1), key.pool.tickSpacing());
        }

        checkRange(cache.tickLower, cache.tickUpper, key.pool.tickSpacing());

        /// floor the tick again because one tick is still not valid tick due to + - baseThreshold
        tickLower = floor(cache.tickLower, key.pool.tickSpacing());
        tickUpper = floor(cache.tickUpper, key.pool.tickSpacing());
    }

    /// @dev Common checks for valid tick inputs.
    /// @param tickLower The lower tick of the range
    /// @param tickUpper The upper tick of the range
    /// @param tickSpacing The pool tick spacing
    function checkRange(int24 tickLower, int24 tickUpper, int24 tickSpacing) internal pure {
        require(tickLower < tickUpper, "TLU");
        require(tickLower >= TickMath.MIN_TICK, "TLM");
        require(tickUpper <= TickMath.MAX_TICK, "TUM");
        require(tickLower % tickSpacing == 0, "TLI");
        require(tickUpper % tickSpacing == 0, "TUI");
    }

    /// @dev Gets amounts of token0 and token1 that can be stored in range of upper and lower ticks
    /// @param pool Uniswap V3 pool
    /// @param amount0Desired The desired amount of token0
    /// @param amount1Desired The desired amount of token1
    /// @param _tickLower The lower tick of the range
    /// @param _tickUpper The upper tick of the range
    /// @return amount0 amounts of token0 that can be stored in range
    /// @return amount1 amounts of token1 that can be stored in range
    function getAmountsForTicks(
        IUniswapV3Pool pool,
        uint256 amount0Desired,
        uint256 amount1Desired,
        int24 _tickLower,
        int24 _tickUpper
    )
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint128 liquidity = getLiquidityForAmounts(pool, amount0Desired, amount1Desired, _tickLower, _tickUpper);

        (amount0, amount1) = getAmountsForLiquidity(pool, liquidity, _tickLower, _tickUpper);
    }

    /// @dev Wrapper around `LiquidityAmounts.getLiquidityForAmounts()`.
    /// @param pool Uniswap V3 pool
    /// @param amount0 The amount of token0
    /// @param amount1 The amount of token1
    /// @param _tickLower The lower tick of the range
    /// @param _tickUpper The upper tick of the range
    /// @return The maximum amount of liquidity that can be held amount0 and amount1
    function getLiquidityForAmounts(
        IUniswapV3Pool pool,
        uint256 amount0,
        uint256 amount1,
        int24 _tickLower,
        int24 _tickUpper
    )
        internal
        view
        returns (uint128)
    {
        (uint160 sqrtRatioX96,,,,,,) = pool.slot0();

        return LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(_tickLower),
            TickMath.getSqrtRatioAtTick(_tickUpper),
            amount0,
            amount1
        );
    }

    /// @dev Wrapper around `LiquidityAmounts.getAmountsForLiquidity()`.
    /// @param pool Uniswap V3 pool
    /// @param liquidity  The liquidity being valued
    /// @param _tickLower The lower tick of the range
    /// @param _tickUpper The upper tick of the range
    /// @return amounts of token0 and token1 that corresponds to liquidity
    function getAmountsForLiquidity(
        IUniswapV3Pool pool,
        uint128 liquidity,
        int24 _tickLower,
        int24 _tickUpper
    )
        internal
        view
        returns (uint256, uint256)
    {
        (uint160 sqrtRatioX96,,,,,,) = pool.slot0();
        return LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96, TickMath.getSqrtRatioAtTick(_tickLower), TickMath.getSqrtRatioAtTick(_tickUpper), liquidity
        );
    }

    /// @dev Get imbalanced token
    /// @param amount0Desired The desired amount of token0
    /// @param amount1Desired The desired amount of token1
    /// @param amount0 Amounts of token0 that can be stored in base range
    /// @param amount1 Amounts of token1 that can be stored in base range
    /// @return zeroGreaterOne true if token0 is imbalanced. False if token1 is imbalanced
    function amountsDirection(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0,
        uint256 amount1
    )
        internal
        pure
        returns (bool zeroGreaterOne)
    {
        zeroGreaterOne =
            (amount0Desired - amount0) * amount1Desired > (amount1Desired - amount1) * amount0Desired ? true : false;
    }

    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`.
    function floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }
}
