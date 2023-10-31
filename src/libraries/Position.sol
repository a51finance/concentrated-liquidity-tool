// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "./PoolActions.sol";
import "../libraries/FixedPoint128.sol";
import { ICLTBase } from "../interfaces/ICLTBase.sol";

library Position {
    uint128 internal constant MAX_UINT128 = type(uint128).max;

    struct Data {
        bytes32 strategyId;
        uint256 liquidityShare;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function update(
        ICLTBase.StrategyData storage self,
        uint128 liquidityAdded,
        uint256 share,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Added,
        uint256 amount1Added
    )
        internal
    {
        uint256 balance0 = amount0Desired - amount0Added;
        uint256 balance1 = amount1Desired - amount1Added;

        if (balance0 > 0 || balance1 > 0) {
            self.balance0 += balance0;
            self.balance1 += balance1;
        }

        if (share > 0) {
            self.totalShares += share;
            self.uniswapLiquidity += liquidityAdded;
        }
    }

    function updateStrategy(
        ICLTBase.StrategyData storage self,
        ICLTBase.StrategyKey memory key,
        bytes memory status,
        uint128 liquidity,
        uint256 balance0,
        uint256 balance1
    )
        internal
    {
        self.key = key;

        self.balance0 = balance0;
        self.balance1 = balance1;

        self.actionStatus = status;
        self.uniswapLiquidity = liquidity; // this can affect feeGrowth if it's zero updated?
    }

    function updatePositionFee(ICLTBase.StrategyData storage self) internal {
        PoolActions.updatePosition(self.key);

        (uint256 fees0, uint256 fees1) =
            PoolActions.collectPendingFees(self.key, MAX_UINT128, MAX_UINT128, address(this));

        self.feeGrowthInside0LastX128 += FullMath.mulDiv(fees0, FixedPoint128.Q128, self.uniswapLiquidity);
        self.feeGrowthInside1LastX128 += FullMath.mulDiv(fees1, FixedPoint128.Q128, self.uniswapLiquidity);
    }
}
