// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

interface ILiquidityDistribution {
    error InvalidCaller();

    function checkInputData(bytes[] memory data) external;
}
