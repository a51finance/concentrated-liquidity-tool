// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library LDFLibrary {
    // Normalize weights to sum to 1e18 (fixed-point arithmetic)
    function normalizeWeights(uint256[] memory weights, uint256 totalWeight) internal pure returns (uint256[] memory) {
        for (uint256 i = 0; i < weights.length; i++) {
            weights[i] = (weights[i] * 1e18) / totalWeight;
        }
        return weights;
    }

    // Compute the Cumulative Allocation Function (CAF)
    function caf(
        int24[] memory ticks,
        uint256[] memory weights,
        int24 startTick,
        int24 endTick,
        int24 tickSpacing
    )
        internal
        pure
        returns (uint256 cumulativeWeight)
    {
        for (uint256 i = 0; i < ticks.length; i++) {
            if (ticks[i] >= startTick && ticks[i] <= endTick && (ticks[i] - startTick) % tickSpacing == 0) {
                cumulativeWeight += weights[i];
            }
        }
    }

    // Compute the Inverse Cumulative Allocation Function (ICAF)
    function icaf(
        int24[] memory ticks,
        uint256[] memory weights,
        uint256 targetWeight
    )
        internal
        pure
        returns (int24 tick)
    {
        uint256 cumulativeWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            cumulativeWeight += weights[i];
            if (cumulativeWeight >= targetWeight) {
                return ticks[i];
            }
        }
        revert("Target weight exceeds total weight");
    }

    // Recompute weights for redistribution (based on LDF function type)
    function computeLDFWeights(
        int24 centralTick,
        int24 tickSpread,
        uint8 distributionType,
        int24 tickSpacing
    )
        internal
        pure
        returns (int24[] memory ticks, uint256[] memory weights, uint256 totalWeight)
    {
        uint256 count = uint256((int256(tickSpread * 2)) / tickSpacing + 1);
        ticks = new int24[](count);
        weights = new uint256[](count);
        totalWeight = 0;

        for (uint256 i = 0; i < count; i++) {
            int24 tick = centralTick - tickSpread + int24(int256(i)) * tickSpacing;
            ticks[i] = tick;

            if (distributionType == 1) {
                weights[i] = 1e18; // Uniform
            } else if (distributionType == 2) {
                weights[i] = uint256(1e18 / (1 + abs(centralTick - tick))); // Geometric
            } else if (distributionType == 3) {
                weights[i] = (tick % 2 == 0) ? uint256(1e18 / (1 + abs(centralTick - tick))) : 1e15; // Carpeted
                    // Geometric
            } else if (distributionType == 4) {
                // Double Geometric
                int24 midTick = centralTick;
                weights[i] = (tick <= midTick)
                    ? uint256(1e18 / (1 + abs(midTick - tick))) // Left geometric segment
                    : uint256(1e18 / (1 + abs(tick - midTick))); // Right geometric segment
            } else if (distributionType == 5) {
                // Carpeted Double Geometric
                int24 midTick = centralTick;
                weights[i] = (tick <= midTick)
                    ? ((tick % 2 == 0) ? uint256(1e18 / (1 + abs(midTick - tick))) : 1e15) // Left carpeted segment
                    : ((tick % 2 == 0) ? uint256(1e18 / (1 + abs(tick - midTick))) : 1e15); // Right carpeted segment
            } else if (distributionType == 6) {
                // BuyTheDipGeometric
                weights[i] = uint256(1e18 / (1 + abs(centralTick - tick)) ** 2); // Skewed towards lower ticks
            } else {
                weights[i] = 1e15; // Baseline carpeted liquidity for uniform spread
            }

            totalWeight += weights[i];
        }

        weights = normalizeWeights(weights, totalWeight);
    }

    // Helper function: Absolute value
    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x < 0 ? -x : x);
    }
}
