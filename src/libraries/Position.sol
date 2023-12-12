// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import { Constants } from "./Constants.sol";
import { PoolActions } from "./PoolActions.sol";
import { ICLTBase } from "../interfaces/ICLTBase.sol";
import { FixedPoint128 } from "../libraries/FixedPoint128.sol";

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

/// @notice Positions represent an owner in A51 liquidity
library Position {
    function update(
        ICLTBase.StrategyData storage self,
        uint128 liquidityAdded,
        uint256 share,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Added,
        uint256 amount1Added
    )
        public
    {
        uint256 balance0 = amount0Desired - amount0Added;
        uint256 balance1 = amount1Desired - amount1Added;

        if (balance0 > 0 || balance1 > 0) {
            self.account.balance0 += balance0;
            self.account.balance1 += balance1;
        }

        if (share > 0) {
            self.account.totalShares += share;
            self.account.uniswapLiquidity += liquidityAdded;
        }
    }

    function updateForCompound(
        ICLTBase.StrategyData storage self,
        uint128 liquidityAdded,
        uint256 amount0Added,
        uint256 amount1Added
    )
        public
    {
        if (liquidityAdded > 0) {
            self.account.balance0 = amount0Added;
            self.account.balance1 = amount1Added;

            self.account.uniswapLiquidity += liquidityAdded;
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
        public
    {
        self.key = key;

        self.account.balance0 = balance0;
        self.account.balance1 = balance1;

        self.actionStatus = status;
        self.account.uniswapLiquidity = liquidity; // this can affect feeGrowth if it's zero updated?
    }

    function updateStrategyState(
        ICLTBase.StrategyData storage self,
        address newOwner,
        uint256 managementFee,
        uint256 performanceFee,
        bytes memory newActions
    )
        public
    {
        self.owner = newOwner;
        self.managementFee = managementFee;
        self.performanceFee = performanceFee;
        self.actions = newActions; // this can effect balances and actionStatus?
        self.actionStatus = ""; // alert user during update that all previous data will be cleared
    }

    /// update this function after strategy global implementation
    function updatePositionFee(ICLTBase.StrategyData storage self) public {
        PoolActions.updatePosition(self.key);

        (uint256 fees0, uint256 fees1) =
            PoolActions.collectPendingFees(self.key, Constants.MAX_UINT128, Constants.MAX_UINT128, address(this));

        self.account.fee0 += fees0;
        self.account.fee1 += fees1;

        self.account.feeGrowthInside0LastX128 +=
            FullMath.mulDiv(fees0, FixedPoint128.Q128, self.account.uniswapLiquidity);

        self.account.feeGrowthInside1LastX128 +=
            FullMath.mulDiv(fees1, FixedPoint128.Q128, self.account.uniswapLiquidity);
    }
}
