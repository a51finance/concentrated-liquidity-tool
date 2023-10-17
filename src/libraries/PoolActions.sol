// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "./SafeCastExtended.sol";

import { StrategyKey } from "../base/Structs.sol";

import "../interfaces/ICLTBase.sol";
import "../interfaces/ICLTPayments.sol";

import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/// @title Liquidity and ticks functions
/// @notice Provides functions for computing liquidity and ticks for token amounts and prices
library PoolActions {
    using SafeCastExtended for uint256;

    function updatePosition(StrategyKey memory key) internal returns (uint128 liquidity) {
        (liquidity,,,,) = getPositionLiquidity(key);

        if (liquidity > 0) {
            key.pool.burn(key.tickLower, key.tickUpper, 0);
        }
    }

    function burnLiquidity(
        StrategyKey memory key,
        uint128 strategyliquidity
    )
        internal
        returns (uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1)
    {
        (uint128 liquidity,,,,) = getPositionLiquidity(key);
        // bug we can't use above liquidity value it will pull all other strategies liquidity aswell
        // only use above we need to calculate share of any strategy

        if (strategyliquidity > 0) {
            (amount0, amount1) = key.pool.burn(key.tickLower, key.tickUpper, strategyliquidity);

            if (amount0 > 0 || amount1 > 0) {
                (uint256 collect0, uint256 collect1) =
                    key.pool.collect(address(this), key.tickLower, key.tickUpper, type(uint128).max, type(uint128).max);

                (fees0, fees1) = (collect0 - amount0, collect1 - amount1);
            }
        }
    }

    function burnUserLiquidity(
        StrategyKey storage key,
        uint128 strategyliquidity,
        uint256 userSharePercentage
    )
        internal
        returns (uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1)
    {
        uint256 liquidityRemoved = FullMath.mulDiv(uint256(strategyliquidity), userSharePercentage, 1e18);

        (amount0, amount1) = key.pool.burn(key.tickLower, key.tickUpper, liquidityRemoved.toUint128());

        // collect user liquidity + unclaimed fee both now
        if (amount0 > 0 || amount1 > 0) {
            (uint256 collect0, uint256 collect1) =
                key.pool.collect(address(this), key.tickLower, key.tickUpper, type(uint128).max, type(uint128).max);

            (fees0, fees1) = (collect0 - amount0, collect1 - amount1);
        }
    }

    function mintLiquidity(
        StrategyKey memory key,
        uint256 amount0Desired,
        uint256 amount1Desired
    )
        internal
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        liquidity = getLiquidityForAmounts(key, amount0Desired, amount1Desired);

        (amount0, amount1) = key.pool.mint(
            address(this),
            key.tickLower,
            key.tickUpper,
            liquidity,
            abi.encode(
                ICLTPayments.MintCallbackData({
                    token0: key.pool.token0(),
                    token1: key.pool.token1(),
                    fee: key.pool.fee(),
                    payer: address(this)
                })
            )
        );
    }

    function swapToken(
        IUniswapV3Pool pool,
        bool zeroForOne,
        int256 amountSpecified
    )
        internal
        returns (int256 amount0, int256 amount1)
    {
        // manually specify sqrtPrice limit from bot
        (uint160 sqrtPriceX96,,) = getSqrtRatioX96AndTick(pool);

        uint160 exactSqrtPriceImpact = (sqrtPriceX96 * (1e5 / 2)) / 1e6;

        uint160 sqrtPriceLimitX96 =
            zeroForOne ? sqrtPriceX96 - exactSqrtPriceImpact : sqrtPriceX96 + exactSqrtPriceImpact;

        (amount0, amount1) =
            pool.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, abi.encode(zeroForOne));
    }

    function collectPendingFees(
        StrategyKey memory key,
        uint128 tokensOwed0,
        uint128 tokensOwed1,
        address recipient
    )
        internal
        returns (uint256 collect0, uint256 collect1)
    {
        (collect0, collect1) = key.pool.collect(recipient, key.tickLower, key.tickUpper, tokensOwed0, tokensOwed1);
    }

    function getPositionLiquidity(StrategyKey memory key)
        internal
        view
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        bytes32 positionKey = PositionKey.compute(address(this), key.tickLower, key.tickUpper);
        (liquidity, feeGrowthInside0LastX128, feeGrowthInside1LastX128, tokensOwed0, tokensOwed1) =
            key.pool.positions(positionKey);
    }

    function getLiquidityForAmounts(
        StrategyKey memory key,
        uint256 amount0,
        uint256 amount1
    )
        internal
        view
        returns (uint128)
    {
        (uint160 sqrtRatioX96,,,,,,) = key.pool.slot0();

        return LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(key.tickLower),
            TickMath.getSqrtRatioAtTick(key.tickUpper),
            amount0,
            amount1
        );
    }

    function getAmountsForLiquidity(
        StrategyKey memory key,
        uint128 liquidity
    )
        internal
        view
        returns (uint256, uint256)
    {
        (uint160 sqrtRatioX96,,,,,,) = key.pool.slot0();

        return LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(key.tickLower),
            TickMath.getSqrtRatioAtTick(key.tickUpper),
            liquidity
        );
    }

    function getSqrtRatioX96AndTick(IUniswapV3Pool pool)
        internal
        view
        returns (uint160 sqrtRatioX96, int24 tick, uint16 observationCardinality)
    {
        (sqrtRatioX96, tick,, observationCardinality,,,) = pool.slot0();
    }

    function amountsDirection(
        bool zeroForOne,
        uint256 amount0Recieved,
        uint256 amount1Recieved,
        uint256 amount0,
        uint256 amount1
    )
        internal
        pure
        returns (uint256 reserves0, uint256 reserves1)
    {
        (reserves0, reserves1) = zeroForOne
            ? (amount0Recieved - amount0, amount1Recieved + amount1)
            : (amount0Recieved + amount0, amount1Recieved - amount1);
    }

    function checkRange(int24 tickLower, int24 tickUpper, int24 tickSpacing) internal pure {
        require(tickLower < tickUpper, "TLU");
        require(tickLower >= TickMath.MIN_TICK, "TLM");
        require(tickUpper <= TickMath.MAX_TICK, "TUM");
        require(tickLower % tickSpacing == 0, "TLI");
        require(tickUpper % tickSpacing == 0, "TUI");
    }
}
