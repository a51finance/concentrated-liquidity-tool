// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import { PoolActions } from "./PoolActions.sol";
import { ICLTBase } from "../interfaces/ICLTBase.sol";

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

library LiquidityShares {
    function getReserves(
        ICLTBase.StrategyKey memory key,
        uint128 liquidity
    )
        public
        returns (uint256 reserves0, uint256 reserves1)
    {
        PoolActions.updatePosition(key);

        // check only for this strategy uniswap liquidity
        if (liquidity > 0) {
            (,,, uint256 earnable0, uint256 earnable1) = PoolActions.getPositionLiquidity(key);

            (uint256 burnable0, uint256 burnable1) = PoolActions.getAmountsForLiquidity(key, liquidity);

            reserves0 = burnable0 + earnable0;
            reserves1 = burnable1 + earnable1;
        }
    }

    function computeLiquidityShare(
        ICLTBase.StrategyKey memory key,
        bool isCompound,
        uint128 strategyliquidity,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 balance0,
        uint256 balance1,
        uint256 totalSupply
    )
        external
        returns (uint256 shares, uint256 amount0, uint256 amount1)
    {
        if (isCompound) {
            (uint256 reserve0, uint256 reserve1) = getReserves(key, strategyliquidity);

            // If total supply > 0, pool can't be empty
            assert(totalSupply == 0 || reserve0 != 0 || reserve1 != 0);
            (shares, amount0, amount1) =
                calculateShare(amount0Max, amount1Max, reserve0 + balance0, reserve1 + balance1, totalSupply);
        } else {
            uint128 liquidity = PoolActions.getLiquidityForAmounts(key, amount0Max, amount1Max);

            (amount0, amount1) = PoolActions.getAmountsForLiquidity(key, liquidity);

            shares = totalSupply == 0 ? uint256(liquidity) : FullMath.mulDiv(totalSupply, liquidity, strategyliquidity);
        }
    }

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
