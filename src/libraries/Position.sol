// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import { ICLTBase } from "../interfaces/ICLTBase.sol";
import { StrategyFeeShares } from "../libraries/StrategyFeeShares.sol";

/// @title  Position
/// @notice Positions store state for indivdual A51 strategy and manage th
library Position {
    /// @notice updates the liquidity and balance of strategy
    /// @param self The individual strategy position to update
    /// @param global The individual global position
    /// @param liquidityAdded A new amount of liquidity added on AMM
    /// @param share The amount of shares minted by strategy
    /// @param amount0Desired The amount of token0 that was paid to mint the given amount of shares
    /// @param amount1Desired The amount of token1 that was paid to mint the given amount of shares
    /// @param amount0Added The actual amount of token0 added on AMM
    /// @param amount1Added The actual amount of token1 added on AMM
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
            bool isExit = getHodlStatus(self);

            self.account.totalShares += share;
            self.account.uniswapLiquidity += liquidityAdded;
            if (isExit == false) global.totalLiquidity += share; //if liquidity HODL it shouldn't added on dex liquidity
        }
    }

    /// @notice updates the position of strategy after fee compound
    /// @param self The individual strategy position to update
    /// @param liquidityAdded A new amount of liquidity added on AMM
    /// @param amount0Added The amount of token0 added to the liquidity position
    /// @param amount1Added The amount of token1 added to the liquidity position
    function updateForCompound(
        ICLTBase.StrategyData storage self,
        uint128 liquidityAdded,
        uint256 amount0Added,
        uint256 amount1Added
    )
        public
    {
        // fees amounts that are not added on AMM will be in held in contract balance
        self.account.balance0 = amount0Added;
        self.account.balance1 = amount1Added;

        self.account.fee0 = 0;
        self.account.fee1 = 0;

        self.account.uniswapLiquidity += liquidityAdded;
    }

    /// @notice updates the strategy and mint new position on AMM
    /// @param self The individual strategy position to update
    /// @param global The mapping containing all global positions
    /// @param key A51 strategy key details
    /// @param status Additional data of strategy passed through by the modules contract
    /// @param liquidity A new amount of liquidity added on AMM
    /// @param balance0 Amount of token0 left that are not added on AMM
    /// @param balance1 Amount of token1 left that are not added on AMM
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

        // remaining assets are held in contract
        self.account.balance0 = balance0;
        self.account.balance1 = balance1;

        self.actionStatus = status;
        self.account.uniswapLiquidity = liquidity;

        bool isExit = getHodlStatus(self);

        // if liquidity is on HODL it shouldn't recieve fee shares but calculations will remain for existing users
        if (isExit == false) globalAccount.totalLiquidity += self.account.totalShares;

        // fee should remain for non-compounding strategy existing users
        if (self.isCompound) {
            self.account.fee0 = 0;
            self.account.fee1 = 0;
        }

        // assigning again feeGrowth here because if position ticks are changed then calculations will be messed
        self.account.feeGrowthOutside0LastX128 = globalAccount.feeGrowthInside0LastX128;
        self.account.feeGrowthOutside1LastX128 = globalAccount.feeGrowthInside1LastX128;
    }

    /// @notice updates the info of strategy
    /// @param self The individual strategy position to update
    /// @param newOwner The address of owner to update
    /// @param managementFee The percentage of management fee to update
    /// @param performanceFee The percentage of performance fee to update
    /// @param newActions The ids of new modes to update
    /// @dev The status of previous actions will be overwrite after update
    function updateStrategyState(
        ICLTBase.StrategyData storage self,
        address newOwner,
        uint256 managementFee,
        uint256 performanceFee,
        bytes memory newActions
    )
        public
    {
        self.actions = newActions;

        if (self.owner != newOwner) self.owner = newOwner;
        if (self.managementFee != managementFee) self.managementFee = managementFee;
        if (self.performanceFee != performanceFee) self.performanceFee = performanceFee;

        bool isExit = getHodlStatus(self);

        if (isExit) {
            self.actionStatus = abi.encode(0, isExit);
        } else {
            self.actionStatus = "";
        }
    }

    function getHodlStatus(ICLTBase.StrategyData storage self) public view returns (bool isExit) {
        if (self.actionStatus.length > 0) {
            (, isExit) = abi.decode(self.actionStatus, (uint256, bool));
        }
    }
}
