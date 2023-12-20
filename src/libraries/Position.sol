// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import { Constants } from "./Constants.sol";
import { PoolActions } from "./PoolActions.sol";
import { ICLTBase } from "../interfaces/ICLTBase.sol";
import { FixedPoint128 } from "../libraries/FixedPoint128.sol";
import { StrategyFeeShares } from "../libraries/StrategyFeeShares.sol";

import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

/// @notice Positions represent an owner in A51 liquidity
library Position {
    function update(
        ICLTBase.StrategyData storage self,
        StrategyFeeShares.GlobalAccount storage global,
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
            global.totalLiquidity += liquidityAdded;
            self.account.uniswapLiquidity += liquidityAdded;
        }
    }

    function updateForCompound(
        ICLTBase.StrategyData storage self,
        StrategyFeeShares.GlobalAccount storage global,
        uint128 liquidityAdded,
        uint256 amount0Added,
        uint256 amount1Added
    )
        public
    {
        if (liquidityAdded > 0) {
            // fees amounts that are not added on AMM will be in held in contract balance
            self.account.balance0 = amount0Added;
            self.account.balance1 = amount1Added;

            self.account.fee0 = 0;
            self.account.fee1 = 0;

            global.totalLiquidity += liquidityAdded;
            self.account.uniswapLiquidity += liquidityAdded;
        }
    }

    function updateStrategy(
        ICLTBase.StrategyData storage self,
        mapping(bytes32 => StrategyFeeShares.GlobalAccount) storage global,
        ICLTBase.StrategyKey memory key,
        bytes memory status,
        uint128 liquidity,
        uint256 balance0,
        uint256 balance1
    )
        public
    {
        StrategyFeeShares.GlobalAccount storage globalAccount =
            global[keccak256(abi.encodePacked(key.pool, key.tickLower, key.tickUpper))];

        self.key = key;

        self.account.balance0 = balance0;
        self.account.balance1 = balance1;

        self.actionStatus = status;
        self.account.uniswapLiquidity = liquidity; // this can affect feeGrowth if it's zero updated?
        globalAccount.totalLiquidity += liquidity;

        self.account.fee0 = 0;
        self.account.fee1 = 0;

        self.account.feeGrowthInside0LastX128 = globalAccount.feeGrowthInside0LastX128;
        self.account.feeGrowthInside1LastX128 = globalAccount.feeGrowthInside1LastX128;
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
}
