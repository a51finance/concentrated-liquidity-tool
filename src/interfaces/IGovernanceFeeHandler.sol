//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

interface IGovernanceFeeHandler {
    error StrategyFeeLimitExceed();
    error ManagementFeeLimitExceed();
    error PerformanceFeeLimitExceed();
    error LPAutomationFeeLimitExceed();

    struct ProtocolFeeRegistry {
        uint256 lpAutomationFee;
        uint256 strategyCreationFee;
        uint256 protcolFeeOnManagement;
        uint256 protcolFeeOnPerformance;
    }

    function publicStrategyFeeRegistry()
        external
        returns (
            uint256 lpAutomationFee,
            uint256 strategyCreationFee,
            uint256 protcolFeeOnManagement,
            uint256 protcolFeeOnPerformance
        );

    function privateStrategyFeeRegistry()
        external
        returns (
            uint256 lpAutomationFee,
            uint256 strategyCreationFee,
            uint256 protcolFeeOnManagement,
            uint256 protcolFeeOnPerformance
        );

    event PublicFeeRegistryUpdated(ProtocolFeeRegistry newRegistry);

    event PrivateFeeRegistryUpdated(ProtocolFeeRegistry newRegistry);
}
