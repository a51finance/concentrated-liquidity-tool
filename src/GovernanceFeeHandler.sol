// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import { Constants } from "./libraries/Constants.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IGovernanceFeeHandler } from "./interfaces/IGovernanceFeeHandler.sol";

/// @title  GovernanceFeeHandler
/// @notice GovernanceFeeHandler contains methods for managing governance fee parameters in strategies
contract GovernanceFeeHandler is IGovernanceFeeHandler, Ownable {
    ProtocolFeeRegistry private _publicStrategyFeeRegistry;
    ProtocolFeeRegistry private _privateStrategyFeeRegistry;

    constructor(
        ProtocolFeeRegistry memory publicStrategyFeeRegistry_,
        ProtocolFeeRegistry memory privateStrategyFeeRegistry_
    )
        Ownable()
    {
        _publicStrategyFeeRegistry = publicStrategyFeeRegistry_;
        _privateStrategyFeeRegistry = privateStrategyFeeRegistry_;
    }

    /// @inheritdoc IGovernanceFeeHandler
    function setPublicFeeRegistry(ProtocolFeeRegistry calldata newPublicStrategyFeeRegistry)
        external
        override
        onlyOwner
    {
        _checkLimit(newPublicStrategyFeeRegistry);

        _publicStrategyFeeRegistry = newPublicStrategyFeeRegistry;

        emit PublicFeeRegistryUpdated(newPublicStrategyFeeRegistry);
    }

    /// @inheritdoc IGovernanceFeeHandler
    function setPrivateFeeRegistry(ProtocolFeeRegistry calldata newPrivateStrategyFeeRegistry)
        external
        override
        onlyOwner
    {
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
        require(feeParams.lpAutomationFee < Constants.MAX_AUTOMATION_FEE, "LPAutomationFeeLimitExceed");
        require(feeParams.strategyCreationFee < Constants.MAX_STRATEGY_CREATION_FEE, "StrategyFeeLimitExceed");
        require(feeParams.protcolFeeOnManagement < Constants.MAX_PROTCOL_MANAGEMENT_FEE, "ManagementFeeLimitExceed");
        require(feeParams.protcolFeeOnPerformance < Constants.MAX_PROTCOL_PERFORMANCE_FEE, "PerformanceFeeLimitExceed");
    }
}
