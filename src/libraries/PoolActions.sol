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
        (liquidity,,) = getPositionLiquidity(key);

        if (liquidity > 0) {
            key.pool.burn(key.tickLower, key.tickUpper, 0);
        }
    }

    function burnLiquidity(
        StrategyKey memory key,
        uint128 strategyliquidity,
        address recipient
    )
        internal
        returns (uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1)
    {
        (uint128 liquidity,,) = getPositionLiquidity(key);
        // bug we can't use above liquidity value it will pull all other strategies liquidity aswell

        if (strategyliquidity > 0) {
            (amount0, amount1) = key.pool.burn(key.tickLower, key.tickUpper, strategyliquidity);

            if (amount0 > 0 || amount1 > 0) {
                (uint256 collect0, uint256 collect1) =
                    key.pool.collect(recipient, key.tickLower, key.tickUpper, type(uint128).max, type(uint128).max);

                (fees0, fees1) = (collect0 - amount0, collect1 - amount1);
            }
        }
    }

    function burnUserLiquidity(
        StrategyKey calldata key,
        uint256 userSharePercentage,
        address recipient
    )
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        (uint128 liquidity,,) = getPositionLiquidity(key);

        uint256 liquidityRemoved = FullMath.mulDiv(uint256(liquidity), userSharePercentage, 1e18);

        (amount0, amount1) = key.pool.burn(key.tickLower, key.tickUpper, liquidityRemoved.toUint128());

        if (amount0 > 0 || amount1 > 0) {
            (amount0, amount0) =
                key.pool.collect(recipient, key.tickLower, key.tickUpper, amount0.toUint128(), amount1.toUint128());
        }
    }

    function mintLiquidity(
        StrategyKey memory key,
        uint256 amount0Desired,
        uint256 amount1Desired,
        address payer
    )
        internal
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        liquidity = getLiquidityForAmounts(key, amount0Desired, amount1Desired);

        if (liquidity > 0) {
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
                        payer: payer
                    })
                )
            );
        }
    }

    function swapToken(IUniswapV3Pool pool, address recipient, bool zeroForOne, int256 amountSpecified) internal {
        (uint160 sqrtPriceX96,,) = getSqrtRatioX96AndTick(pool);

        uint160 exactSqrtPriceImpact = (sqrtPriceX96 * (1e5 / 2)) / 1e6;

        uint160 sqrtPriceLimitX96 =
            zeroForOne ? sqrtPriceX96 - exactSqrtPriceImpact : sqrtPriceX96 + exactSqrtPriceImpact;

        pool.swap(recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, abi.encode(zeroForOne));
    }

    function collectPendingFees(
        StrategyKey calldata key,
        address recipient
    )
        internal
        returns (uint256 collect0, uint256 collect1)
    {
        updatePosition(key);

        (collect0, collect1) =
            key.pool.collect(recipient, key.tickLower, key.tickUpper, type(uint128).max, type(uint128).max);
    }

    function getPositionLiquidity(StrategyKey memory key)
        internal
        view
        returns (uint128 liquidity, uint128 tokensOwed0, uint128 tokensOwed1)
    {
        bytes32 positionKey = PositionKey.compute(address(this), key.tickLower, key.tickUpper);
        (liquidity,,, tokensOwed0, tokensOwed1) = key.pool.positions(positionKey);
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

    function checkRange(int24 tickLower, int24 tickUpper, int24 tickSpacing) internal pure {
        require(tickLower < tickUpper, "TLU");
        require(tickLower >= TickMath.MIN_TICK, "TLM");
        require(tickUpper <= TickMath.MAX_TICK, "TUM");
        require(tickLower % tickSpacing == 0, "TLI");
        require(tickUpper % tickSpacing == 0, "TUI");
    }
}
