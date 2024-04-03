// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import { ICLTTwapQuoter } from "./interfaces/ICLTTwapQuoter.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { TickMath } from "@thruster-blast/contracts/libraries/TickMath.sol";
import { IThrusterPool } from "@thruster-blast/interfaces/IThrusterPool.sol";
import { OracleLibrary } from "@thruster-blast/contracts/libraries/OracleLibrary.sol";

contract CLTTwapQuoter is ICLTTwapQuoter, Ownable {
    /// @inheritdoc ICLTTwapQuoter
    uint32 public override twapDuration;

    /// @inheritdoc ICLTTwapQuoter
    mapping(address => PoolStrategy) public override poolStrategy;

    constructor() Ownable() {
        twapDuration = 3600;
    }

    function checkDeviation(IThrusterPool pool) external view override {
        int24 twap = calculateTwap(pool);
        (int24 tick,) = getCurrentTick(pool);
        int24 deviation = tick > twap ? tick - twap : twap - tick;
        require(poolStrategy[address(pool)].maxTwapDeviation > deviation, "MaxTwapDeviationExceeded");
    }

    /// @notice This function calculates the current twap of pool
    /// @param pool The pool address
    function calculateTwap(IThrusterPool pool) internal view returns (int24 twap) {
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
    function getTwap(IThrusterPool pool) public view override returns (int24 twap) {
        (,, uint16 observationIndex, uint16 observationCardinality,,,) = pool.slot0();

        (uint32 lastTimeStamp,,,) = pool.observations((observationIndex + 1) % observationCardinality);

        uint32 timeDiff = uint32(block.timestamp) - lastTimeStamp;

        uint32 duration = poolStrategy[address(pool)].twapDuration;

        if (duration == 0) {
            duration = twapDuration;
        }

        (twap,) = OracleLibrary.consult(address(pool), timeDiff > duration ? duration : timeDiff);
    }

    /// @notice This function fetches the current tick of the pool
    /// @param pool The pool address
    function getCurrentTick(IThrusterPool pool) public view returns (int24 tick, uint160 sqrtPriceX96) {
        (sqrtPriceX96, tick,,,,,) = pool.slot0();
    }

    function setStandardTwapDuration(uint32 _twapDuration) external onlyOwner {
        require(_twapDuration != 0, "InvalidInput");
        twapDuration = _twapDuration;
    }
}
