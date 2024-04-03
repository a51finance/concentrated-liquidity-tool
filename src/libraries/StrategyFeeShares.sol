// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import { ICLTBase } from "../interfaces/ICLTBase.sol";

import { Constants } from "../libraries/Constants.sol";
import { PoolActions } from "../libraries/PoolActions.sol";
import { FixedPoint128 } from "../libraries/FixedPoint128.sol";

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { FullMath } from "@thruster-blast/contracts/libraries/FullMath.sol";

/// @title  StrategyFeeShares
/// @notice StrategyFeeShares contains methods for tracking fees owed to the strategy w.r.t global fees
library StrategyFeeShares {
    /// @param positionFee0 The uncollected amount of token0 owed to the global position as of the last computation
    /// @param positionFee1 The uncollected amount of token1 owed to the global position as of the last computation
    /// @param totalLiquidity The sum of liquidity of all strategies having global position ticks
    /// @param feeGrowthInside0LastX128 The all-time fee growth in token0, per unit of liquidity, inside the position's
    /// tick boundaries
    /// @param feeGrowthInside1LastX128 The all-time fee growth in token1, per unit of liquidity, inside the position's
    /// tick boundaries
    struct GlobalAccount {
        uint256 positionFee0;
        uint256 positionFee1;
        uint256 totalLiquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }

    /// @notice Collects total uncollected fee owed to the global position from AMM & updates all-time fee growth
    /// @param self The individual global position to update
    /// @param key A51 strategy key details
    /// @return account The position info struct of the given global position
    function updateGlobalStrategyFees(
        mapping(bytes32 => GlobalAccount) storage self,
        ICLTBase.StrategyKey memory key
    )
        external
        returns (GlobalAccount storage account)
    {
        account = self[keccak256(abi.encodePacked(key.pool, key.tickLower, key.tickUpper))];

        PoolActions.updatePosition(key);

        if (account.totalLiquidity > 0) {
            (uint256 fees0, uint256 fees1) =
                PoolActions.collectPendingFees(key, Constants.MAX_UINT128, Constants.MAX_UINT128, address(this));

            account.positionFee0 += fees0;
            account.positionFee1 += fees1;

            account.feeGrowthInside0LastX128 += FullMath.mulDiv(fees0, FixedPoint128.Q128, account.totalLiquidity);
            account.feeGrowthInside1LastX128 += FullMath.mulDiv(fees1, FixedPoint128.Q128, account.totalLiquidity);
        }
    }

    /// @notice Credits accumulated fees to a strategy from global position
    /// @param self The individual strategy position to update
    /// @param global The individual global position
    /// @dev strategy will not recieve fee share from global position because it's liquidity is HODL in contract balance
    /// during activation of exit mode
    function updateStrategyFees(
        ICLTBase.StrategyData storage self,
        GlobalAccount storage global
    )
        external
        returns (uint256 total0, uint256 total1)
    {
        (uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128) =
            (global.feeGrowthInside0LastX128, global.feeGrowthInside1LastX128);

        bool isExit;

        if (self.actionStatus.length > 0) {
            (, isExit) = abi.decode(self.actionStatus, (uint256, bool));
        }

        if (isExit == false) {
            // calculate accumulated fees
            total0 = uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 - self.account.feeGrowthOutside0LastX128,
                    self.account.totalShares,
                    FixedPoint128.Q128
                )
            );

            total1 = uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 - self.account.feeGrowthOutside1LastX128,
                    self.account.totalShares,
                    FixedPoint128.Q128
                )
            );
        }

        // precesion loss expected here so rounding the value to zero to prevent underflow
        (, global.positionFee0) = SafeMath.trySub(global.positionFee0, total0);
        (, global.positionFee1) = SafeMath.trySub(global.positionFee1, total1);

        // update the position
        self.account.fee0 += total0;
        self.account.fee1 += total1;

        // assign fee growth from upper global of ticks
        self.account.feeGrowthOutside0LastX128 = feeGrowthInside0LastX128;
        self.account.feeGrowthOutside1LastX128 = feeGrowthInside1LastX128;

        // increament fee growth for all the users inside strategy
        if (self.account.totalShares > 0) {
            self.account.feeGrowthInside0LastX128 +=
                FullMath.mulDiv(total0, FixedPoint128.Q128, self.account.totalShares);

            self.account.feeGrowthInside1LastX128 +=
                FullMath.mulDiv(total1, FixedPoint128.Q128, self.account.totalShares);
        }
    }
}
