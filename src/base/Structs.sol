// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0;
pragma abicoder v2;

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

struct StrategyKey {
    IUniswapV3Pool pool;
    int24 tickLower;
    int24 tickUpper;
}

struct DepositParams {
    bytes32 strategyId;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    address recipient;
}

struct UpdatePositionParams {
    uint256 tokenId;
    uint256 amount0Desired;
    uint256 amount1Desired;
}

struct WithdrawParams {
    StrategyKey key;
    address recipient;
    uint256 tokenId;
    uint256 userSharePercentage;
}

struct ShiftLiquidityParams {
    StrategyKey key; // new ticks will be given this time
    bytes32 strategyId;
    bool zeroForOne;
    uint256 amount0;
    uint256 amount1;
    uint256 userShare;
    int256 swapAmount;
}

struct ClaimFeesParams {
    StrategyKey key;
    address recipient;
    uint256 tokenId;
}

struct PositionActions {
    uint8 mode;
    uint64[] exitStrategy;
    uint64[] rebasePreference;
    uint64[] liquidityDistribution;
}

struct ActionsData {
    bytes32[] exitStrategyData;
    bytes32[] rebasePreferenceData;
    bytes32[] liquidityDistributionData;
}

struct StrategyData {
    StrategyKey key;
    bytes32 actions;
    bytes32 actionsData; // assembly operations needed to merge actions & data into single byte32 word { figure out }
    bool isCompound;
    uint256 balance0;
    uint256 balance1;
    uint256 totalShares;
    uint128 uniswapLiquidity;
}
