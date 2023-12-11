// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import { ICLTBase } from "../interfaces/ICLTBase.sol";

import { Constants } from "../libraries/Constants.sol";
import { PoolActions } from "../libraries/PoolActions.sol";
import { FixedPoint128 } from "../libraries/FixedPoint128.sol";

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

library StrategyFeeShares {
    struct GlobalAccount {
        uint256 positionFee0;
        uint256 positionFee1;
        uint256 totalLiquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }

    struct StrategyAccount {
        ICLTBase.StrategyKey key;
        uint256 liquidityShare;
        uint256 fee0;
        uint256 fee1;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }

    function updateGlobalStrategyFees(
        mapping(bytes32 => GlobalAccount) storage self,
        ICLTBase.StrategyKey memory key
    )
        external
    {
        GlobalAccount storage account = self[keccak256(abi.encodePacked(key.pool, key.tickLower, key.tickUpper))];

        PoolActions.updatePosition(key);

        (uint256 fees0, uint256 fees1) =
            PoolActions.collectPendingFees(key, Constants.MAX_UINT128, Constants.MAX_UINT128, address(this));

        account.positionFee0 += fees0;
        account.positionFee1 += fees1;

        account.feeGrowthInside0LastX128 += FullMath.mulDiv(fees0, FixedPoint128.Q128, account.totalLiquidity);
        account.feeGrowthInside1LastX128 += FullMath.mulDiv(fees1, FixedPoint128.Q128, account.totalLiquidity);
    }

    function updateStrategyFees(StrategyAccount storage self, GlobalAccount storage globalPosition) external {
        (uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128) =
            (globalPosition.feeGrowthInside0LastX128, globalPosition.feeGrowthInside1LastX128);

        uint256 total0 = uint128(
            FullMath.mulDiv(
                feeGrowthInside0LastX128 - self.feeGrowthInside0LastX128, self.liquidityShare, FixedPoint128.Q128
            )
        );

        uint256 total1 = uint128(
            FullMath.mulDiv(
                feeGrowthInside1LastX128 - self.feeGrowthInside1LastX128, self.liquidityShare, FixedPoint128.Q128
            )
        );

        globalPosition.positionFee0 -= total0;
        globalPosition.positionFee1 -= total1;

        self.fee0 += total0;
        self.fee1 += total1;

        self.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
    }
}
