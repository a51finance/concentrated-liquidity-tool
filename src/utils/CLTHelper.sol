// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.15;

import { LiquidityAmounts } from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ICLTBase } from "../interfaces/ICLTBase.sol";

contract CLTHelper {
    function decodePositionActions(bytes memory actions) external pure returns (ICLTBase.PositionActions memory) {
        ICLTBase.PositionActions memory modules = abi.decode(actions, (ICLTBase.PositionActions));
        return modules;
    }

    function decodeActionStatus(bytes memory actionStatus)
        external
        pure
        returns (uint256 rebaseCount, bool isExit, uint256 lastUpdateTimeStamp, uint256 manualSwapsCount)
    {
        if (actionStatus.length > 0) {
            if (actionStatus.length == 64) {
                (rebaseCount, isExit) = abi.decode(actionStatus, (uint256, bool));
            } else {
                (rebaseCount, isExit, lastUpdateTimeStamp, manualSwapsCount) =
                    abi.decode(actionStatus, (uint256, bool, uint256, uint256));
            }
        }
    }

    function getStrategyReserves(
        address poolAddress,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidityAmount
    )
        external
        view
        returns (uint256 reserves0, uint256 reserves1)
    {
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddress).slot0();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        if (liquidityAmount > 0) {
            (reserves0, reserves1) =
                LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, liquidityAmount);
        }
    }
}
