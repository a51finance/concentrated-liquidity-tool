// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import { ICLTBase } from "../ICLTBase.sol";

interface IExitStrategy {
    error InvalidCaller();

    function checkInputData(ICLTBase.StrategyPayload memory data) external returns (bool);
}
