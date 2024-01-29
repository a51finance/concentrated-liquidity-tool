// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import { ICLTBase } from "../ICLTBase.sol";

interface ILiquidityDistributionStrategy {
    function checkInputData(ICLTBase.StrategyPayload memory data) external returns (bool);
}
