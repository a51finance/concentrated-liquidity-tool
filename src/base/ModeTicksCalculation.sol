// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { StrategyKey } from "./Structs.sol";
import { OracleLibrary } from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

abstract contract ModeTicksCalculation {
    uint32 twapDuration = 300;

    function shiftLeft(
        StrategyKey memory key,
        int24 positionWidth // given by the user i.e. no of ticks
    )
        internal
        view
        returns (int24 tickLower, int24 tickUpper)
    {
        int24 currentTick = getTwap(key.pool);
        int24 tickSpacing = key.pool.tickSpacing();

        if (currentTick < key.tickLower) {
            (, currentTick,,,,,) = key.pool.slot0();

            currentTick = floorTick(currentTick, tickSpacing);

            tickLower = currentTick - tickSpacing;
            tickUpper = tickLower - positionWidth;
        }
    }

    function shiftRight(
        StrategyKey memory key,
        int24 positionWidth
    )
        internal
        view
        returns (int24 tickLower, int24 tickUpper)
    {
        int24 currentTick = getTwap(key.pool);
        int24 tickSpacing = key.pool.tickSpacing();

        if (currentTick > key.tickUpper) {
            (, currentTick,,,,,) = key.pool.slot0();

            currentTick = floorTick(currentTick, tickSpacing);

            tickUpper = currentTick - tickSpacing;
            tickLower = tickUpper - positionWidth;
        }
    }

    function shiftBothSide() internal view { }

    function getTwap(IUniswapV3Pool pool) internal view returns (int24 twap) {
        (,, uint16 observationIndex, uint16 observationCardinality,,,) = pool.slot0();

        (uint32 lastTimeStamp,,,) = pool.observations((observationIndex + 1) % observationCardinality);

        uint32 timeDiff = uint32(block.timestamp) - lastTimeStamp;

        (twap,) = OracleLibrary.consult(address(pool), timeDiff > twapDuration ? twapDuration : timeDiff);
    }

    function floorTick(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }
}