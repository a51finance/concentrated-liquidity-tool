// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Owned } from "@solmate/auth/Owned.sol";
import { Constants } from "./libraries/Constants.sol";
import { IGovernanceFeeHandler } from "./interfaces/IGovernanceFeeHandler.sol";

contract GovernanceFeeHandler is IGovernanceFeeHandler, Owned {
    ProtocolFeeRegistry public override publicStrategyFeeRegistry;
    ProtocolFeeRegistry public override privateStrategyFeeRegistry;

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

    function setPublicFeeRegistry(ProtocolFeeRegistry calldata newPublicStrategyFeeRegistry) external onlyOwner {
        _checkLimit(newPublicStrategyFeeRegistry);

        publicStrategyFeeRegistry = newPublicStrategyFeeRegistry;

        emit PublicFeeRegistryUpdated(newPublicStrategyFeeRegistry);
    }

    function setPrivateFeeRegistry(ProtocolFeeRegistry calldata newPrivateStrategyFeeRegistry) external onlyOwner {
        _checkLimit(newPrivateStrategyFeeRegistry);

        privateStrategyFeeRegistry = newPrivateStrategyFeeRegistry;

        emit PrivateFeeRegistryUpdated(newPrivateStrategyFeeRegistry);
    }

    function _checkLimit(ProtocolFeeRegistry calldata feeParams) private pure {
        if (feeParams.lpAutomationFee > Constants.MAX_AUTOMATION_FEE) revert LPAutomationFeeLimitExceed();
        if (feeParams.strategyCreationFee > Constants.MAX_STRATEGY_CREATION_FEE) revert StrategyFeeLimitExceed();
        if (feeParams.protcolFeeOnManagement > Constants.MAX_PROTCOL_MANAGEMENT_FEE) revert ManagementFeeLimitExceed();
        if (feeParams.protcolFeeOnPerformance > Constants.MAX_PROTCOL_PERFORMANCE_FEE) {
            revert PerformanceFeeLimitExceed();
        }
    }
}
