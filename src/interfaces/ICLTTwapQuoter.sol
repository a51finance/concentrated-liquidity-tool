//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import { IAlgebraPool } from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";

interface ICLTTwapQuoter {
    error InvalidInput();
    error MaxTwapDeviationExceeded();

    /// @param twapDuration Period of time that we observe for price slippage
    /// @param maxTwapDeviation Maximum deviation of time waited avarage price in ticks
    struct PoolStrategy {
        uint32 twapDuration;
        int24 maxTwapDeviation;
    }

    function checkDeviation(IAlgebraPool pool) external;

    function twapDuration() external view returns (uint32);

    function getTwap(IAlgebraPool pool) external view returns (int24 twap);

    /// @notice Returns twap duration & max twap deviation for each pool
    function poolStrategy(address pool) external returns (uint32 twapDuration, int24 maxTwapDeviation);
}
