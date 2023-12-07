// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase } from "./interfaces/ICLTBase.sol";
import { IRebaseStrategy } from "./interfaces/modules/IRebaseStrategy.sol";
import { IExitStrategy } from "./interfaces/modules/IExitStrategy.sol";
import { IGovernanceFeeHandler } from "./interfaces/IGovernanceFeeHandler.sol";
import { ILiquidityDistributionStrategy } from "./interfaces/modules/ILiquidityDistributionStrategy.sol";

import { Owned } from "@solmate/auth/Owned.sol";
import { Constants } from "./libraries/Constants.sol";

contract CLTModules is Owned {
    mapping(bytes32 => address) public modeVaults;

    mapping(bytes32 => mapping(bytes32 => bool)) public modulesActions;

    constructor(address owner) Owned(owner) { }

    /// @notice Whitlist new ids for advance strategy modes
    /// @dev New id can only be added for only rebase, exit & liquidity advance modes
    /// @param moduleKey Hash of the module for which is need to be updated
    /// @param newModule Array of new mode ids to be added against advance modes
    function setNewModule(bytes32 moduleKey, bytes32 newModule) external onlyOwner {
        _checkModuleKey(moduleKey);

        modulesActions[moduleKey][newModule] = true;
    }

    /// @notice updates the address of mode's vault
    /// @param moduleKey Hash of the module for which is need to be updated
    /// @param modeVault New address of mode's vault
    function setModuleAddress(bytes32 moduleKey, address modeVault) external onlyOwner {
        _checkModuleKey(moduleKey);

        modeVaults[moduleKey] = modeVault;
    }

    function toggleModule(bytes32 moduleKey, bytes32 module) external onlyOwner {
        _checkModuleKey(moduleKey);

        modulesActions[moduleKey][module] = !modulesActions[moduleKey][module];
    }

    /// @notice Validates the strategy encoded input data
    function _validateInputData(bytes32 mode, ICLTBase.StrategyPayload[] memory array) private {
        address vault = modeVaults[mode];

        for (uint256 i = 0; i < array.length; i++) {
            if (mode == Constants.REBASE_STRATEGY) {
                IRebaseStrategy(vault).checkInputData(array[i]);
            } else if (mode == Constants.EXIT_STRATEGY) {
                IExitStrategy(vault).checkInputData(array[i]);
            } else if (mode == Constants.LIQUIDITY_DISTRIBUTION) {
                ILiquidityDistributionStrategy(vault).checkInputData(array[i]);
            } else {
                revert();
            }
        }
    }

    function validateModes(
        ICLTBase.PositionActions calldata actions,
        uint256 managementFee,
        uint256 performanceFee
    )
        external
    {
        if (managementFee > Constants.MAX_MANAGEMENT_FEE) revert IGovernanceFeeHandler.ManagementFeeLimitExceed();

        if (performanceFee > Constants.MAX_PERFORMANCE_FEE) revert IGovernanceFeeHandler.PerformanceFeeLimitExceed();

        if (actions.mode < 0 && actions.mode > 4) revert();

        if (actions.exitStrategy.length > 0) {
            _checkModeIds(Constants.EXIT_STRATEGY, actions.exitStrategy);
            _validateInputData(Constants.EXIT_STRATEGY, actions.exitStrategy);
        }

        if (actions.rebaseStrategy.length > 0) {
            _checkModeIds(Constants.REBASE_STRATEGY, actions.rebaseStrategy);
            _validateInputData(Constants.REBASE_STRATEGY, actions.rebaseStrategy);
        }

        if (actions.liquidityDistribution.length > 0) {
            _checkModeIds(Constants.LIQUIDITY_DISTRIBUTION, actions.liquidityDistribution);
            _validateInputData(Constants.LIQUIDITY_DISTRIBUTION, actions.liquidityDistribution);
        }
    }

    function _checkModeIds(bytes32 mode, ICLTBase.StrategyPayload[] memory array) private view {
        for (uint256 i = 0; i < array.length; i++) {
            if (!modulesActions[mode][array[i].actionName]) revert();
        }
    }

    function _checkModuleKey(bytes32 moduleKey) private pure {
        require(
            moduleKey == Constants.MODE || moduleKey == Constants.REBASE_STRATEGY
                || moduleKey == Constants.EXIT_STRATEGY || moduleKey == Constants.LIQUIDITY_DISTRIBUTION,
            "IM"
        );
    }
}
