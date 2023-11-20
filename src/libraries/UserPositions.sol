// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import { Constants } from "./Constants.sol";
import { PoolActions } from "./PoolActions.sol";

import { ICLTBase } from "../interfaces/ICLTBase.sol";

import { Position } from "../libraries/Position.sol";
import { FixedPoint128 } from "../libraries/FixedPoint128.sol";

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

library UserPositions {
    function updateUserPosition(
        Position.Data storage self,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128
    )
        public
    {
        self.tokensOwed0 += uint128(
            FullMath.mulDiv(
                feeGrowthInside0LastX128 - self.feeGrowthInside0LastX128, self.liquidityShare, FixedPoint128.Q128
            )
        );

        self.tokensOwed1 += uint128(
            FullMath.mulDiv(
                feeGrowthInside1LastX128 - self.feeGrowthInside1LastX128, self.liquidityShare, FixedPoint128.Q128
            )
        );

        self.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
    }

    function claimPositionAmounts(
        Position.Data storage self,
        uint128 tokensOwed0,
        uint128 tokensOwed1,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128
    )
        public
        returns (uint128 total0, uint128 total1)
    {
        total0 = tokensOwed0
            + uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 - self.feeGrowthInside0LastX128, self.liquidityShare, FixedPoint128.Q128
                )
            );

        total1 = tokensOwed1
            + uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 - self.feeGrowthInside1LastX128, self.liquidityShare, FixedPoint128.Q128
                )
            );

        self.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;

        self.tokensOwed0 = 0;
        self.tokensOwed1 = 0;
    }
}
