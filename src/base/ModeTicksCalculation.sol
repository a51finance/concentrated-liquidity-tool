// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase } from "../interfaces/ICLTBase.sol";
import { OracleLibrary } from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/// @title ModeTicksCalculation
/// @notice Provides functions for computing ticks for basic modes of strategy
abstract contract ModeTicksCalculation {
    uint32 twapDuration = 300;

    /// @notice Computes new tick lower and upper for the individual strategy downside
    /// @dev shift left will trail the strategy position closer to the cuurent tick, current tick will be one tick left
    /// from position
    /// @param key A51 strategy key details
    /// @return tickLower The lower tick of the range
    /// @return tickUpper The upper tick of the range
    function shiftLeft(ICLTBase.StrategyKey memory key) internal view returns (int24 tickLower, int24 tickUpper) {
        int24 currentTick = getTwap(key.pool);
        int24 tickSpacing = key.pool.tickSpacing();

        if (currentTick < key.tickLower) {
            (, currentTick,,,,,) = key.pool.slot0();

            currentTick = floorTick(currentTick, tickSpacing);

            int24 positionWidth = getPositionWidth(currentTick, key.tickLower, key.tickUpper);

            tickLower = currentTick + tickSpacing;
            tickUpper = floorTick(tickLower + positionWidth, tickSpacing);
        }
    }

    /// @notice Computes new tick lower and upper for the individual strategy upside
    /// @dev shift right will trail the strategy position closer to the cuurent tick, current tick will be one tick
    /// right from position
    /// @param key A51 strategy key details
    /// @return tickLower The lower tick of the range
    /// @return tickUpper The upper tick of the range
    function shiftRight(ICLTBase.StrategyKey memory key) internal view returns (int24 tickLower, int24 tickUpper) {
        int24 currentTick = getTwap(key.pool);
        int24 tickSpacing = key.pool.tickSpacing();

        if (currentTick > key.tickUpper) {
            (, currentTick,,,,,) = key.pool.slot0();

            currentTick = floorTick(currentTick, tickSpacing);

            int24 positionWidth = getPositionWidth(currentTick, key.tickLower, key.tickUpper);

            tickUpper = currentTick - tickSpacing;
            tickLower = floorTick(tickUpper - positionWidth, tickSpacing);
        }
    }

    /// @notice Computes new tick lower and upper for the individual strategy downside or upside
    /// @dev it will trail the strategy position closer to the cuurent tick
    /// @param key A51 strategy key details
    /// @return tickLower The lower tick of the range
    /// @return tickUpper The upper tick of the range
    function shiftBothSide(ICLTBase.StrategyKey memory key) internal view returns (int24 tickLower, int24 tickUpper) {
        int24 currentTick = getTwap(key.pool);
        if (currentTick < key.tickLower) return shiftLeft(key);
        if (currentTick > key.tickUpper) return shiftRight(key);
    }

    /// @notice Calculates time-weighted means of tick and liquidity for a given pool
    /// @param pool The address of the Pool
    /// @dev Check price has not moved a lot recently. This mitigates price
    /// manipulation during shifting of position
    /// @return twap The time-weighted average price
    function getTwap(IUniswapV3Pool pool) internal view returns (int24 twap) {
        (,, uint16 observationIndex, uint16 observationCardinality,,,) = pool.slot0();

        (uint32 lastTimeStamp,,,) = pool.observations((observationIndex + 1) % observationCardinality);

        uint32 timeDiff = uint32(block.timestamp) - lastTimeStamp;

        (twap,) = OracleLibrary.consult(address(pool), timeDiff > twapDuration ? twapDuration : timeDiff);
    }

    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`
    /// @param tick The current tick of pool
    /// @param tickSpacing The tick spacing of pool
    /// @return floor value of tick
    function floorTick(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    /// @notice Returns the number of ticks between lower & upper tick
    /// @param currentTick The current tick of pool
    /// @param tickLower The lower tick of strategy
    /// @param tickUpper The upper tick of strategy
    /// @return width The total count of ticks
    function getPositionWidth(
        int24 currentTick,
        int24 tickLower,
        int24 tickUpper
    )
        internal
        pure
        returns (int24 width)
    {
        width = (currentTick - tickLower) + (tickUpper - currentTick);
    }
}
