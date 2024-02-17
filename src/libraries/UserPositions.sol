// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import { ICLTBase } from "../interfaces/ICLTBase.sol";

import { SafeCastExtended } from "./SafeCastExtended.sol";
import { FixedPoint128 } from "../libraries/FixedPoint128.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title  UserPositions
/// @notice UserPositions store additional state for tracking fees owed to the user compound or no compound strategy
library UserPositions {
    using SafeCastExtended for uint256;

    struct Data {
        bytes32 strategyId;
        uint256 liquidityShare;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /// @notice Collects up to a maximum amount of fees owed to a user from the strategy fees
    /// @param self The individual user position to update
    /// @param feeGrowthInside0LastX128 The all-time fee growth in token0, per unit of liquidity in strategy
    /// @param feeGrowthInside1LastX128 The all-time fee growth in token1, per unit of liquidity in strategy
    function updateUserPosition(
        Data storage self,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128
    )
        public
    {
        self.tokensOwed0 += FullMath.mulDiv(
            feeGrowthInside0LastX128 - self.feeGrowthInside0LastX128, self.liquidityShare, FixedPoint128.Q128
        ).toUint128();

        self.tokensOwed1 += FullMath.mulDiv(
            feeGrowthInside1LastX128 - self.feeGrowthInside1LastX128, self.liquidityShare, FixedPoint128.Q128
        ).toUint128();

        self.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
    }

    /// @notice Collects up to a maximum amount of fees owed to a user poistion in non-compounding strategy
    /// @param self The individual user position to update
    /// @param strategy The individual strategy position
    /// @return total0 The amount of fees collected in token0
    /// @return total1 The amount of fees collected in token1
    function claimFeeForNonCompounders(
        Data storage self,
        ICLTBase.StrategyData storage strategy
    )
        public
        returns (uint128 total0, uint128 total1)
    {
        (uint128 tokensOwed0, uint128 tokensOwed1) = (self.tokensOwed0, self.tokensOwed1);

        (uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128) =
            (strategy.account.feeGrowthInside0LastX128, strategy.account.feeGrowthInside1LastX128);

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

        self.tokensOwed0 = total0;
        self.tokensOwed1 = total1;

        // precesion loss expected here so rounding the value to zero to prevent underflow
        (, strategy.account.fee0) = SafeMath.trySub(strategy.account.fee0, total0);
        (, strategy.account.fee1) = SafeMath.trySub(strategy.account.fee1, total1);
    }

    /// @notice Collects up to a maximum amount of fees owed to a user poistion in compounding strategy
    /// @param self The individual user position to update
    /// @param strategy The individual strategy position
    /// @return fee0 The amount of fees collected in token0
    /// @return fee1 The amount of fees collected in token1
    function claimFeeForCompounders(
        Data storage self,
        ICLTBase.StrategyData storage strategy
    )
        public
        returns (uint256 fee0, uint256 fee1)
    {
        fee0 = FullMath.mulDiv(strategy.account.fee0, self.liquidityShare, strategy.account.totalShares);
        fee1 = FullMath.mulDiv(strategy.account.fee1, self.liquidityShare, strategy.account.totalShares);

        (, strategy.account.fee0) = SafeMath.trySub(strategy.account.fee0, fee0);
        (, strategy.account.fee1) = SafeMath.trySub(strategy.account.fee1, fee1);
    }
}
