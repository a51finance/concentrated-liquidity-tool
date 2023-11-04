// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import "../ICLTBase.sol";

interface ILiquidityDistribution {
    error InvalidCaller();

    function checkInputData(ICLTBase.StrategyDetail memory data) external returns (bool);
}
