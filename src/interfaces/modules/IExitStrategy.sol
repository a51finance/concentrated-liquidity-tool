// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

interface IExitStrategy {
    error InvalidCaller();

    function checkInputData(bytes[] memory data) external;
}
