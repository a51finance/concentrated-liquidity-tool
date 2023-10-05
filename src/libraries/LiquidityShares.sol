// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "./PoolActions.sol";

library LiquidityShares {
    function getReserves(StrategyKey memory key)
        internal
        returns (uint256 burnable0, uint256 burnable1, uint256 earnable0, uint256 earnable1, uint128 liquidity)
    {
        PoolActions.updatePosition(key);

        if (liquidity > 0) {
            (liquidity, earnable0, earnable1) = PoolActions.getPositionLiquidity(key);

            (burnable0, burnable1) =
                PoolActions.getAmountsForLiquidity(key.pool, liquidity, key.tickLower, key.tickUpper);
        }
    }

    function computeLiquidityShare(
        StrategyKey memory key,
        bool isCompound,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 balance0,
        uint256 balance1,
        uint256 totalSupply
    )
        internal
        returns (uint256 shares, uint256 amount0, uint256 amount1)
    {
        if (isCompound) {
            (uint256 res0, uint256 res1, uint256 fee0, uint256 fee1,) = getReserves(key);

            uint256 reserve0 = res0 + fee0 + balance0;
            uint256 reserve1 = res1 + fee1 + balance1;

            // If total supply > 0, pool can't be empty
            assert(totalSupply == 0 || reserve0 != 0 || reserve1 != 0);
            (shares, amount0, amount1) = calculateShare(amount0Max, amount1Max, reserve0, reserve1, totalSupply);
        }
    }

    function calculateShare(
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply
    )
        internal
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
