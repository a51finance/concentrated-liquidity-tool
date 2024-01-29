// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import { PoolActions } from "./PoolActions.sol";
import { ICLTBase } from "../interfaces/ICLTBase.sol";

import { FullMath } from "@cryptoalgebra/core/contracts/libraries/FullMath.sol";

/// @title  LiquidityShares
/// @notice Provides functions for computing liquidity amounts and shares for individual strategy
library LiquidityShares {
    /// @notice Returns the token reserves for individual strategy position in pool
    /// @param key A51 strategy key details
    /// @param liquidity The amount of liquidity for this strategy
    /// @return reserves0 The amount of token0 in the liquidity position
    /// @return reserves1 The amount of token1 in the liquidity position
    function getReserves(
        ICLTBase.StrategyKey memory key,
        uint128 liquidity
    )
        public
        returns (uint256 reserves0, uint256 reserves1)
    {
        PoolActions.updatePosition(key);

        // check only for this strategy uniswap liquidity
        // earnable0 & earnable1 will always returns zero becuase fee already claimed in updateGlobal
        if (liquidity > 0) {
            (,,, uint256 earnable0, uint256 earnable1) = PoolActions.getPositionLiquidity(key);

            (uint256 burnable0, uint256 burnable1) = PoolActions.getAmountsForLiquidity(key, liquidity);

            reserves0 = burnable0 + earnable0;
            reserves1 = burnable1 + earnable1;
        }
    }

    /// @notice Mints shares to the recipient based on the amount of tokens recieved.
    /// @param strategy The individual strategy position to mint shares for
    /// @param amount0Max The desired amount of token0 to be spent
    /// @param amount1Max The desired amount of token1 to be spent
    /// @return shares The amount of share minted to the sender
    /// @return amount0 The amount of token0 needs to transfered from sender to strategy
    /// @return amount1 The amount of token1 needs to transfered from sender to strategy
    function computeLiquidityShare(
        ICLTBase.StrategyData storage strategy,
        uint256 amount0Max,
        uint256 amount1Max
    )
        external
        returns (uint256 shares, uint256 amount0, uint256 amount1)
    {
        // check existing liquidity before the add
        (uint256 reserve0, uint256 reserve1) = getReserves(strategy.key, strategy.account.uniswapLiquidity);

        // includes unused balance + fees (if componding strategy otherwise not)
        reserve0 += strategy.account.balance0;
        reserve1 += strategy.account.balance1;

        // If total supply > 0, strategy can't be empty
        assert(strategy.account.totalShares == 0 || reserve0 != 0 || reserve1 != 0);

        (shares, amount0, amount1) =
            calculateShare(amount0Max, amount1Max, reserve0, reserve1, strategy.account.totalShares);
    }

    /// @dev Calculates the largest possible `amount0` and `amount1` such that
    /// they're in the same proportion as total amounts, but not greater than
    /// `amount0Desired` and `amount1Desired` respectively.
    /// @param amount0Max The desired amount of token0 to be spent
    /// @param amount1Max The desired amount of token1 to be spent
    /// @param reserve0 The strategy total holdings of token0
    /// @param reserve1 The strategy total holdings of token1
    /// @param totalSupply Total amount of shares minted from current strategy
    /// @return shares The amount of share minted to the sender
    /// @return amount0 The amount of token0 needs to transfered from sender to strategy
    /// @return amount1 The amount of token1 needs to transfered from sender to strategy
    function calculateShare(
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply
    )
        public
        pure
        returns (uint256 shares, uint256 amount0, uint256 amount1)
    {
        if (totalSupply == 0) {
            // For first deposit, just use the amounts desired
            amount0 = amount0Max;
            amount1 = amount1Max;
            shares = amount0 > amount1 ? amount0 : amount1; // max
        } else if (reserve0 == 0) {
            amount1 = amount1Max;
            shares = FullMath.mulDiv(amount1, totalSupply, reserve1);
        } else if (reserve1 == 0) {
            amount0 = amount0Max;
            shares = FullMath.mulDiv(amount0, totalSupply, reserve0);
        } else {
            amount0 = FullMath.mulDiv(amount1Max, reserve0, reserve1);
            if (amount0 < amount0Max) {
                amount1 = amount1Max;
                shares = FullMath.mulDiv(amount1, totalSupply, reserve1);
            } else {
                amount0 = amount0Max;
                amount1 = FullMath.mulDiv(amount0, reserve1, reserve0);
                shares = FullMath.mulDiv(amount0, totalSupply, reserve0);
            }
        }
    }
}
