// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase } from "../ICLTBase.sol";

interface ILiquidityDistributionStrategy {
    error InvalidCaller();

    function checkInputData(ICLTBase.StrategyPayload memory data) external returns (bool);
}
