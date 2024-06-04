// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import { ICLTTwapQuoter } from "./interfaces/ICLTTwapQuoter.sol";

import { Owned } from "@solmate/auth/Owned.sol";
import { TickMath } from "@cryptoalgebra/integral-core/contracts/libraries/TickMath.sol";
import { OracleLibrary } from "@cryptoalgebra/plugin/contracts/libraries/integration/OracleLibrary.sol";

import { IAlgebraPool } from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";
import { IVolatilityOracle } from "@cryptoalgebra/plugin/contracts/interfaces/plugins/IVolatilityOracle.sol";

contract CLTTwapQuoter is ICLTTwapQuoter, Owned {
    /// @inheritdoc ICLTTwapQuoter
    uint32 public override twapDuration;

    /// @inheritdoc ICLTTwapQuoter
    mapping(address => PoolStrategy) public override poolStrategy;

    constructor(address _owner) Owned(_owner) {
        twapDuration = 3600;
    }

    function checkDeviation(IAlgebraPool pool) external view override {
        int24 twap = calculateTwap(pool);
        (int24 tick,) = getCurrentTick(pool);
        int24 deviation = tick > twap ? tick - twap : twap - tick;

        if (deviation > poolStrategy[address(pool)].maxTwapDeviation) revert MaxTwapDeviationExceeded();
    }

    /// @notice This function calculates the current twap of pool
    /// @param pool The pool address
    function calculateTwap(IAlgebraPool pool) internal view returns (int24 twap) {
        uint128 inRangeLiquidity = pool.liquidity();

        if (inRangeLiquidity == 0) {
            (, uint160 sqrtPriceX96) = getCurrentTick(pool);
            twap = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        } else {
            twap = getTwap(pool);
        }
    }

    /// @notice Calculates time-weighted means of tick and liquidity for a given pool
    /// @param pool The address of the Pool
    /// @dev Check price has not moved a lot recently. This mitigates price
    /// manipulation during shifting of position
    /// @return twap The time-weighted average price
    function getTwap(IAlgebraPool pool) public view override returns (int24 twap) {
        IVolatilityOracle oracle = IVolatilityOracle(pool.plugin());

        uint16 observationIndex = oracle.timepointIndex();

        uint16 oldestIndex;
        // check if we have overflow in the past
        uint16 nextIndex = observationIndex + 1; // considering overflow

        (bool initialized,,,,,,) = oracle.timepoints(nextIndex);

        if (initialized) {
            oldestIndex = nextIndex;
        }

        (, uint32 lastTimeStamp,,,,,) = oracle.timepoints(oldestIndex);

        uint32 timeDiff = uint32(block.timestamp) - lastTimeStamp;
        uint32 duration = poolStrategy[address(pool)].twapDuration;

        if (duration == 0) {
            duration = twapDuration;
        }

        twap = OracleLibrary.consult(address(oracle), timeDiff > duration ? duration : timeDiff);
    }

    /// @notice This function fetches the current tick of the pool
    /// @param pool The pool address
    function getCurrentTick(IAlgebraPool pool) public view returns (int24 tick, uint160 sqrtPriceX96) {
        (sqrtPriceX96, tick,,,,) = pool.globalState();
    }

    function setStandardTwapDuration(uint32 _twapDuration) external onlyOwner {
        if (_twapDuration == 0) revert InvalidInput();
        twapDuration = _twapDuration;
    }
}
