// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "../base/Structs.sol";

library Position {
    struct Data {
        bytes32 strategyId;
        uint256 liquidityShare;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
    }

    function update(
        StrategyData storage self,
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
}
