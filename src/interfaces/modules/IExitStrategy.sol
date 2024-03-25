// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import { ICLTBase } from "../ICLTBase.sol";

interface IExitStrategy {
    function checkInputData(ICLTBase.StrategyPayload memory data) external returns (bool);
}
