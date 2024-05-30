//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import { ICLTBase } from "./ICLTBase.sol";

interface ICLTModules {
    error InvalidMode();
    error InvalidStrategyAction();

    /// @notice Validates the strategy inputs
    /// @param actions The ids of all actions selected for new strategy creation
    /// @param managementFee  The value of strategist management fee on strategy
    /// @param performanceFee The value of strategist perofrmance fee on strategy
    function validateModes(
        ICLTBase.PositionActions calldata actions,
        uint256 managementFee,
        uint256 performanceFee
    )
        external;
}
