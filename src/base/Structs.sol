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

struct WithdrawParams {
    StrategyKey key;
    address recipient;
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
}

struct PositionActions {
    uint64[] modes;
    uint64[] exitStrategy;
    uint64[] rebasePreference;
    uint64[] liquidityDistribution;
}

struct StrategyData {
    StrategyKey key;
    bytes32 positionActions;
    bool isCompound;
    uint256 balance0;
    uint256 balance1;
    uint256 totalShares;
}
