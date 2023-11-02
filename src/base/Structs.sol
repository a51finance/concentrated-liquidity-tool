// // SPDX-License-Identifier: GPL-3.0

// pragma solidity >=0.6.0;
// pragma abicoder v2;

// import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// /// @param pool The Uniswap V3 pool
// /// @param tickLower The lower tick of the A51's LP position
// /// @param tickUpper The upper tick of the A51's LP position
// struct StrategyKey {
//     IUniswapV3Pool pool;
//     int24 tickLower;
//     int24 tickUpper;
// }

// /// @param amount0Desired The desired amount of token0 to be spent,
// /// @param amount1Desired The desired amount of token1 to be spent,
// /// @param amount0Min The minimum amount of token0 to spend, which serves as a slippage check,
// /// @param amount1Min The minimum amount of token1 to spend, which serves as a slippage check,
// /// @param recipient account that should receive the shares in terms of A51's NFT
// struct DepositParams {
//     bytes32 strategyId;
//     uint256 amount0Desired;
//     uint256 amount1Desired;
//     uint256 amount0Min;
//     uint256 amount1Min;
//     address recipient;
// }

// /// @param params tokenId The ID of the token for which liquidity is being increased
// /// @param amount0Desired The desired amount of token0 to be spent,
// /// @param amount1Desired The desired amount of token1 to be spent,
// struct UpdatePositionParams {
//     uint256 tokenId;
//     uint256 amount0Desired;
//     uint256 amount1Desired;
// }

// /// @param params tokenId The ID of the token for which liquidity is being decreased
// /// @param liquidity amount The amount by which liquidity will be decreased,
// /// @param recipient Recipient of tokens
// /// @param refundAsETH whether to recieve in WETH or ETH (only valid for WETH/ALT pairs)
// struct WithdrawParams {
//     uint256 tokenId;
//     uint256 liquidity;
//     address recipient;
//     bool refundAsETH;
// }

// /// @param key A51 new position's key with updated ticks
// /// @param strategyId Id of A51's position for which ticks are being updated
// /// @param shouldMint Bool weather liquidity should be added on AMM or hold in contract
// /// @param swapAmount Amount of token0 or token1 to swap before minting new position
// /// @param moduleStatus The encoded data for each of the strategy to track any detail for futher actions
// struct ShiftLiquidityParams {
//     StrategyKey key; // new ticks will be given this time
//     bytes32 strategyId;
//     bool shouldMint;
//     bool zeroForOne;
//     int256 swapAmount;
//     bytes moduleStatus;
// }

// /// @param recipient Recipient of tokens
// /// @param params tokenId The ID of the NFT for which tokens are being collected
// /// @param refundAsETH whether to recieve in WETH or ETH (only valid for WETH/ALT pairs)
// struct ClaimFeesParams {
//     address recipient;
//     uint256 tokenId;
//     bool refundAsETH;
// }

// struct ActionDetails {
//     uint256 mode; // mode can be 1, 2, or 3
//     StrategyDetail[] exitStrategy;
//     StrategyDetail[] rebaseStrategy;
//     StrategyDetail[] liquidityDistribution;
// }

// struct StrategyDetail {
//     bytes32 actionName;
//     bytes data;
// }

// /// @param key A51 position's key details
// /// @param actions Ids of all modes selected by the strategist encoded together in a single hash
// /// @param actionsData Input values for the respective mode encoded in hash & all inputs are encoded together again
// /// @param actionStatus The encoded data for each of the strategy to track any detail for futher actions
// /// @param isCompound Bool weather the strategy has compunding activated or not
// /// @param balance0 Amount of token0 left that are not added on AMM's position
// /// @param balance1 Amount of token0 left that are not added on AMM's position
// /// @param totalShares Total no of shares minted for this A51's strategy
// /// @param uniswapLiquidity Total no of liquidity added on AMM for this strategy
// /// @param feeGrowthInside0LastX128 The fee growth of token0 collected per unit of liquidity for
// /// the entire life of the A51's position
// /// @param feeGrowthInside1LastX128 The fee growth of token1 collected per unit of liquidity for
// /// the entire life of the A51's position
// struct StrategyData {
//     StrategyKey key;
//     bytes actionsData; // assembly operations needed to merge actions & data into single byte32 word { figure out }
//     bytes actionStatus;
//     bool isCompound;
//     uint256 balance0;
//     uint256 balance1;
//     uint256 totalShares;
//     uint128 uniswapLiquidity;
//     uint256 feeGrowthInside0LastX128;
//     uint256 feeGrowthInside1LastX128;
// }
