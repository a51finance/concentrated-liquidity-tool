// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "../ICLTBase.sol";

interface ILiquidityDistribution {
    error InvalidCaller();

    function checkInputData(StrategyDetail memory data) external returns (bool);
}
