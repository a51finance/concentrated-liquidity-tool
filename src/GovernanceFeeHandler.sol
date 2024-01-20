// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Owned } from "@solmate/auth/Owned.sol";
import { Constants } from "./libraries/Constants.sol";
import { IGovernanceFeeHandler } from "./interfaces/IGovernanceFeeHandler.sol";

/// @title  GovernanceFeeHandler
/// @notice GovernanceFeeHandler contains methods for managing governance fee parameters in strategies
contract GovernanceFeeHandler is IGovernanceFeeHandler, Owned {
    /// @notice The protocol fee value in percentage for public strategy,  decimal value <1
    ProtocolFeeRegistry private publicStrategyFeeRegistry;
    /// @notice The protocol fee value in percentage for private strategy, decimal value <1
    ProtocolFeeRegistry private privateStrategyFeeRegistry;

    constructor(
        address _owner,
        ProtocolFeeRegistry memory _publicStrategyFeeRegistry,
        ProtocolFeeRegistry memory _privateStrategyFeeRegistry
    )
        Owned(_owner)
    {
        publicStrategyFeeRegistry = _publicStrategyFeeRegistry;
        privateStrategyFeeRegistry = _privateStrategyFeeRegistry;
    }

    /// @inheritdoc IGovernanceFeeHandler
    function setPublicFeeRegistry(ProtocolFeeRegistry calldata newPublicStrategyFeeRegistry) external onlyOwner {
        _checkLimit(newPublicStrategyFeeRegistry);

        publicStrategyFeeRegistry = newPublicStrategyFeeRegistry;

        emit PublicFeeRegistryUpdated(newPublicStrategyFeeRegistry);
    }

    /// @inheritdoc IGovernanceFeeHandler
    function setPrivateFeeRegistry(ProtocolFeeRegistry calldata newPrivateStrategyFeeRegistry) external onlyOwner {
        _checkLimit(newPrivateStrategyFeeRegistry);

        privateStrategyFeeRegistry = newPrivateStrategyFeeRegistry;

        emit PrivateFeeRegistryUpdated(newPrivateStrategyFeeRegistry);
    }

    /// @inheritdoc IGovernanceFeeHandler
    function getGovernanceFee(bool isPrivate)
        external
        view
        override
        returns (
            uint256 lpAutomationFee,
            uint256 strategyCreationFee,
            uint256 protcolFeeOnManagement,
            uint256 protcolFeeOnPerformance
        )
    {
        if (isPrivate) {
            (lpAutomationFee, strategyCreationFee, protcolFeeOnManagement, protcolFeeOnPerformance) = (
                privateStrategyFeeRegistry.lpAutomationFee,
                privateStrategyFeeRegistry.strategyCreationFee,
                privateStrategyFeeRegistry.protcolFeeOnManagement,
                privateStrategyFeeRegistry.protcolFeeOnPerformance
            );
        } else {
            (lpAutomationFee, strategyCreationFee, protcolFeeOnManagement, protcolFeeOnPerformance) = (
                publicStrategyFeeRegistry.lpAutomationFee,
                publicStrategyFeeRegistry.strategyCreationFee,
                publicStrategyFeeRegistry.protcolFeeOnManagement,
                publicStrategyFeeRegistry.protcolFeeOnPerformance
            );
        }
    }

    /// @dev Common checks for valid fee inputs.
    function _checkLimit(ProtocolFeeRegistry calldata feeParams) private pure {
        if (feeParams.lpAutomationFee > Constants.MAX_AUTOMATION_FEE) revert LPAutomationFeeLimitExceed();
        if (feeParams.strategyCreationFee > Constants.MAX_STRATEGY_CREATION_FEE) revert StrategyFeeLimitExceed();
        if (feeParams.protcolFeeOnManagement > Constants.MAX_PROTCOL_MANAGEMENT_FEE) revert ManagementFeeLimitExceed();
        if (feeParams.protcolFeeOnPerformance > Constants.MAX_PROTCOL_PERFORMANCE_FEE) {
            revert PerformanceFeeLimitExceed();
        }
    }
}
