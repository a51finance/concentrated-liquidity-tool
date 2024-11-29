//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

interface ICLTTwapQuoter {
    error InvalidInput();
    error MaxTwapDeviationExceeded();

    event PoolTwapUpdated(uint32 twapDuration);
    event StandardTwapUpdated(uint32 twapDuration);

    /// @param twapDuration Period of time that we observe for price slippage
    /// @param maxTwapDeviation Maximum deviation of time waited avarage price in ticks
    struct PoolStrategy {
        uint32 twapDuration;
        int24 maxTwapDeviation;
    }

    function checkDeviation(IUniswapV3Pool pool) external;

    function twapDuration() external view returns (uint32);

    function getTwap(IUniswapV3Pool pool) external view returns (int24 twap);

    /// @notice Returns twap duration & max twap deviation for each pool
    function poolStrategy(address pool) external returns (uint32 twapDuration, int24 maxTwapDeviation);
}
