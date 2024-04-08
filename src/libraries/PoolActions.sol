// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import { Constants } from "./Constants.sol";

import { ICLTBase } from "../interfaces/ICLTBase.sol";
import { SafeCastExtended } from "./SafeCastExtended.sol";
import { ICLTPayments } from "../interfaces/ICLTPayments.sol";

import { PositionKey } from "@pancakeswap/v3-periphery/contracts/libraries/PositionKey.sol";
import { LiquidityAmounts } from "@pancakeswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import { FullMath } from "@pancakeswap/v3-core/contracts/libraries/FullMath.sol";
import { TickMath } from "@pancakeswap/v3-core/contracts/libraries/TickMath.sol";
import { IPancakeV3Pool } from "@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Pool.sol";
import { SqrtPriceMath } from "@pancakeswap/v3-core/contracts/libraries/SqrtPriceMath.sol";

/// @title  PoolActions
/// @notice Provides functions for computing and safely managing liquidity on AMM
library PoolActions {
    using SafeCastExtended for int256;
    using SafeCastExtended for uint256;

    /// @notice Returns the liquidity for individual strategy position in pool
    /// @param key A51 strategy key details
    /// @return liquidity The amount of liquidity for this strategy
    function updatePosition(ICLTBase.StrategyKey memory key) external returns (uint128 liquidity) {
        (liquidity,,,,) = getPositionLiquidity(key);

        if (liquidity > 0) {
            key.pool.burn(key.tickLower, key.tickUpper, 0);
        }
    }

    /// @notice Burn complete liquidity of strategy in a range from pool
    /// @param key A51 strategy key details
    /// @param strategyliquidity The amount of liquidity to burn for this strategy
    /// @return amount0 The amount of token0 that was accounted for the decrease in liquidity
    /// @return amount1 The amount of token1 that was accounted for the decrease in liquidity
    /// @return fees0 The amount of fees collected in token0
    /// @return fees1 The amount of fees collected in token1
    function burnLiquidity(
        ICLTBase.StrategyKey memory key,
        uint128 strategyliquidity
    )
        external
        returns (uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1)
    {
        // only use individual liquidity of strategy we need otherwise it will pull all strategies liquidity
        if (strategyliquidity > 0) {
            (amount0, amount1) = key.pool.burn(key.tickLower, key.tickUpper, strategyliquidity);

            if (amount0 > 0 || amount1 > 0) {
                (uint256 collect0, uint256 collect1) =
                    key.pool.collect(address(this), key.tickLower, key.tickUpper, type(uint128).max, type(uint128).max);

                (fees0, fees1) = (collect0 - amount0, collect1 - amount1);
            }
        }
    }

    /// @notice Burn liquidity in share proportion to the strategy's totalSupply
    /// @param strategyliquidity The total amount of liquidity for this strategy
    /// @param userSharePercentage The value of user share in strategy in terms of percentage
    /// @return liquidity The amount of liquidity decrease
    /// @return amount0 The amount of token0 withdrawn to the recipient
    /// @return amount1 The amount of token1 withdrawn to the recipient
    /// @return fees0 The amount of fees collected in token0 to the recipient
    /// @return fees1 The amount of fees collected in token1 to the recipient
    function burnUserLiquidity(
        ICLTBase.StrategyKey storage key,
        uint128 strategyliquidity,
        uint256 userSharePercentage
    )
        external
        returns (uint128 liquidity, uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1)
    {
        if (strategyliquidity > 0) {
            liquidity = (FullMath.mulDiv(uint256(strategyliquidity), userSharePercentage, 1e18)).toUint128();

            (amount0, amount1) = key.pool.burn(key.tickLower, key.tickUpper, liquidity);

            if (amount0 > 0 || amount1 > 0) {
                (uint256 collect0, uint256 collect1) =
                    key.pool.collect(address(this), key.tickLower, key.tickUpper, type(uint128).max, type(uint128).max);

                (fees0, fees1) = (collect0 - amount0, collect1 - amount1);
            }
        }
    }

    /// @notice Adds liquidity for the given strategy/tickLower/tickUpper position
    /// @param amount0Desired The amount of token0 that was paid for the increase in liquidity
    /// @param amount1Desired The amount of token1 that was paid for the increase in liquidity
    /// @return liquidity The amount of liquidity minted for this strategy
    /// @return amount0 The amount of token0 added
    /// @return amount1 The amount of token1 added
    function mintLiquidity(
        ICLTBase.StrategyKey memory key,
        uint256 amount0Desired,
        uint256 amount1Desired
    )
        public
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

    /// @notice Swap token0 for token1, or token1 for token0
    /// @param pool The address of the AMM Pool
    /// @param zeroForOne The direction of swap
    /// @param amountSpecified The amount of tokens to swap
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swapToken(
        IPancakeV3Pool pool,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96
    )
        external
        returns (int256 amount0, int256 amount1)
    {
        (amount0, amount1) = pool.swap(
            address(this),
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            abi.encode(ICLTPayments.SwapCallbackData({ token0: pool.token0(), token1: pool.token1(), fee: pool.fee() }))
        );
    }

    /// @notice Collects up to a maximum amount of fees owed to a specific position to the recipient
    /// @param key A51 strategy key details
    /// @param tokensOwed0 The maximum amount of token0 to collect,
    /// @param tokensOwed1 The maximum amount of token1 to collect
    /// @param recipient The account that should receive the tokens,
    /// @return collect0 The amount of fees collected in token0
    /// @return collect1 The amount of fees collected in token1
    function collectPendingFees(
        ICLTBase.StrategyKey memory key,
        uint128 tokensOwed0,
        uint128 tokensOwed1,
        address recipient
    )
        public
        returns (uint256 collect0, uint256 collect1)
    {
        (collect0, collect1) = key.pool.collect(recipient, key.tickLower, key.tickUpper, tokensOwed0, tokensOwed1);
    }

    /// @notice Claims the trading fees earned and uses it to add liquidity.
    /// @param key A51 strategy key details
    /// @param balance0 Amount of token0 left in strategy that were not added in pool
    /// @param balance1 Amount of token1 left in strategy that were not added in pool
    /// @return liquidity The new liquidity amount as a result of the increase
    /// @return balance0AfterMint The amount of token0 not added to the liquidity position
    /// @return balance1AfterMint The amount of token1 not added to the liquidity position
    function compoundFees(
        ICLTBase.StrategyKey memory key,
        uint256 balance0,
        uint256 balance1
    )
        external
        returns (uint128 liquidity, uint256 balance0AfterMint, uint256 balance1AfterMint)
    {
        (uint256 collect0, uint256 collect1) =
            collectPendingFees(key, Constants.MAX_UINT128, Constants.MAX_UINT128, address(this));

        (uint256 total0, uint256 total1) = (collect0 + balance0, collect1 + balance1);

        if (getLiquidityForAmounts(key, total0, total1) > 0) {
            (liquidity, collect0, collect1) = mintLiquidity(key, total0, total1);
            (balance0AfterMint, balance1AfterMint) = (total0 - collect0, total1 - collect1);
        }
    }

    /// @notice Get the info of the given strategy position
    /// @param key A51 strategy key details
    /// @return liquidity The amount of liquidity of the position
    /// @return feeGrowthInside0LastX128 The fee growth of token0 as of the last action on the individual position
    /// @return feeGrowthInside1LastX128 The fee growth of token1 as of the last action on the individual position
    /// @return tokensOwed0 Amount of token0 owed
    /// @return tokensOwed1 Amount of token1 owed
    function getPositionLiquidity(ICLTBase.StrategyKey memory key)
        public
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

    /// @notice Computes the maximum amount of liquidity received for a given amount of token0, token1, the current
    /// pool prices and the prices at the tick boundaries
    /// @param key A51 strategy key details
    /// @param amount0 The amount of token0 being sent in
    /// @param amount1 The amount of token1 being sent in
    /// @return liquidity The maximum amount of liquidity received
    function getLiquidityForAmounts(
        ICLTBase.StrategyKey memory key,
        uint256 amount0,
        uint256 amount1
    )
        public
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

    /// @notice Computes the token0 and token1 value for a given amount of liquidity, the current
    /// pool prices and the prices at the tick boundaries
    /// @param key A51 strategy key details
    /// @param liquidity The liquidity being valued
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function getAmountsForLiquidity(
        ICLTBase.StrategyKey memory key,
        uint128 liquidity
    )
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint160 sqrtRatioX96, int24 tick,,,,,) = key.pool.slot0();

        int256 amount0Delta;
        int256 amount1Delta;

        if (tick < key.tickLower) {
            amount0Delta = SqrtPriceMath.getAmount0Delta(
                TickMath.getSqrtRatioAtTick(key.tickLower),
                TickMath.getSqrtRatioAtTick(key.tickUpper),
                int256(uint256(liquidity)).toInt128()
            );
        } else if (tick < key.tickUpper) {
            amount0Delta = SqrtPriceMath.getAmount0Delta(
                sqrtRatioX96, TickMath.getSqrtRatioAtTick(key.tickUpper), int256(uint256(liquidity)).toInt128()
            );

            amount1Delta = SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtRatioAtTick(key.tickLower), sqrtRatioX96, int256(uint256(liquidity)).toInt128()
            );
        } else {
            amount1Delta = SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtRatioAtTick(key.tickLower),
                TickMath.getSqrtRatioAtTick(key.tickUpper),
                int256(uint256(liquidity)).toInt128()
            );
        }

        (amount0, amount1) = (uint256(amount0Delta), uint256(amount1Delta));
    }

    /// @notice Look up information about a specific pool
    /// @param pool The address of the AMM Pool
    /// @return sqrtRatioX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// @return tick The current tick of the pool, i.e. according to the last tick transition that was run
    /// @return observationCardinality The current maximum number of observations stored in the pool
    function getSqrtRatioX96AndTick(IPancakeV3Pool pool)
        public
        view
        returns (uint160 sqrtRatioX96, int24 tick, uint16 observationCardinality)
    {
        (sqrtRatioX96, tick,, observationCardinality,,,) = pool.slot0();
    }

    /// @notice Computes the direction of tokens recieved after swap to merge in strategy reserves
    /// @param zeroForOne The direction of swap
    /// @param amount0Recieved The delta of the balance of token0 of the pool
    /// @param amount1Recieved The delta of the balance of token1 of the pool
    /// @param amount0 The amount of token0 in the strategy position
    /// @param amount1 The amount of token1 in the strategy position
    /// @return reserves0 The total amount of token0 in the strategy position
    /// @return reserves1 The total amount of token1 in the strategy position
    function amountsDirection(
        bool zeroForOne,
        uint256 amount0Recieved,
        uint256 amount1Recieved,
        uint256 amount0,
        uint256 amount1
    )
        external
        pure
        returns (uint256 reserves0, uint256 reserves1)
    {
        (reserves0, reserves1) = zeroForOne
            ? (amount0Recieved - amount0, amount1Recieved + amount1)
            : (amount0Recieved + amount0, amount1Recieved - amount1);
    }
}
