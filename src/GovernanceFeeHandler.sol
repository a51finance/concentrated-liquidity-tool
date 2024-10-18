// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Owned } from "@solmate/auth/Owned.sol";
import { Constants } from "./libraries/Constants.sol";
import { IGovernanceFeeHandler } from "./interfaces/IGovernanceFeeHandler.sol";

/// @title  GovernanceFeeHandler
/// @notice GovernanceFeeHandler contains methods for managing governance fee parameters in strategies
contract GovernanceFeeHandler is IGovernanceFeeHandler, Owned {
    /// @notice The protocol fee value in percentage for public strategy,  decimal value <1
    ProtocolFeeRegistry private _publicStrategyFeeRegistry;
    /// @notice The protocol fee value in percentage for private strategy, decimal value <1
    ProtocolFeeRegistry private _privateStrategyFeeRegistry;

    constructor(
        address _owner,
        ProtocolFeeRegistry memory publicStrategyFeeRegistry_,
        ProtocolFeeRegistry memory privateStrategyFeeRegistry_
    )
        Owned(_owner)
    {
        _publicStrategyFeeRegistry = publicStrategyFeeRegistry_;
        _privateStrategyFeeRegistry = privateStrategyFeeRegistry_;
    }

    /// @inheritdoc IGovernanceFeeHandler
    function setPublicFeeRegistry(ProtocolFeeRegistry calldata newPublicStrategyFeeRegistry) external onlyOwner {
        _checkLimit(newPublicStrategyFeeRegistry);

        _publicStrategyFeeRegistry = newPublicStrategyFeeRegistry;

        emit PublicFeeRegistryUpdated(newPublicStrategyFeeRegistry);
    }

    /// @inheritdoc IGovernanceFeeHandler
    function setPrivateFeeRegistry(ProtocolFeeRegistry calldata newPrivateStrategyFeeRegistry) external onlyOwner {
        _checkLimit(newPrivateStrategyFeeRegistry);

        _privateStrategyFeeRegistry = newPrivateStrategyFeeRegistry;

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
                _privateStrategyFeeRegistry.lpAutomationFee,
                _privateStrategyFeeRegistry.strategyCreationFee,
                _privateStrategyFeeRegistry.protcolFeeOnManagement,
                _privateStrategyFeeRegistry.protcolFeeOnPerformance
            );
        } else {
            (lpAutomationFee, strategyCreationFee, protcolFeeOnManagement, protcolFeeOnPerformance) = (
                _publicStrategyFeeRegistry.lpAutomationFee,
                _publicStrategyFeeRegistry.strategyCreationFee,
                _publicStrategyFeeRegistry.protcolFeeOnManagement,
                _publicStrategyFeeRegistry.protcolFeeOnPerformance
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
