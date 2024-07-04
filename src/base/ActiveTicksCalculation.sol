// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Constants } from "../libraries/Constants.sol";
import { ICLTBase } from "../interfaces/ICLTBase.sol";
import { IGovernanceFeeHandler } from "../interfaces/IGovernanceFeeHandler.sol";

/// @title  ModeTicksCalculation
/// @notice Provides functions for computing ticks for basic modes of strategy
abstract contract ActiveTicksCalculation {
    /// @notice Computes new tick lower and upper for the individual strategy downside or upside
    /// @dev it will trail the strategy position closer to the cuurent tick
    /// @param key A51 strategy key details
    /// @return tickLower The lower tick of the range
    /// @return tickUpper The upper tick of the range
    function shiftActive(ICLTBase.StrategyKey memory key, int24 currentTick) internal view returns (int24, int24) {
        int24 tickSpacing = key.pool.tickSpacing();

        (, currentTick,,,,,) = key.pool.slot0();

        int24 positionWidth = getActivePositionWidth(currentTick, key.tickLower, key.tickUpper);

        int24 tickLower = floorTickActive(currentTick - (positionWidth / 2), tickSpacing);
        int24 tickUpper = floorTickActive(currentTick + (positionWidth / 2), tickSpacing);

        return (tickLower, tickUpper);
    }

    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`
    /// @param tick The current tick of pool
    /// @param tickSpacing The tick spacing of pool
    /// @return floor value of tick
    function floorTickActive(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    /// @notice Returns the number of ticks between lower & upper tick
    /// @param currentTick The current tick of pool
    /// @param tickLower The lower tick of strategy
    /// @param tickUpper The upper tick of strategy
    /// @return width The total count of ticks
    function getActivePositionWidth(
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

    /// @param key A51 strategy key details
    /// @param isPrivate Bool weather strategy is open for all users or not
    /// @param amount0 The amount of token0 from which the strategist fee will deduct
    /// @param amount1 The amount of token1 from which the strategist fee will deduct
    /// @param governance Address of protocol owner
    /// @param feeHandler Address of governance fee handler contract.
    function getProtocolFeeses(
        ICLTBase.StrategyKey memory key,
        bool isPrivate,
        uint256 amount0,
        uint256 amount1,
        address governance,
        address feeHandler
    )
        internal
        returns (uint256 fee0, uint256 fee1)
    {
        (uint256 percentage,,,) = IGovernanceFeeHandler(feeHandler).getGovernanceFee(isPrivate);

        if (percentage > 0) {
            if (amount0 > 0) {
                fee0 = (amount0 * percentage) / Constants.WAD;
            }

            if (amount1 > 0) {
                fee1 = (amount1 * percentage) / Constants.WAD;
            }
        }
    }
}
