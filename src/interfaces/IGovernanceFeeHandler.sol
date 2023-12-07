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

    function getGovernanceFee(bool isPrivate)
        external
        view
        returns (
            uint256 lpAutomationFee,
            uint256 strategyCreationFee,
            uint256 protcolFeeOnManagement,
            uint256 protcolFeeOnPerformance
        );

    event PublicFeeRegistryUpdated(ProtocolFeeRegistry newRegistry);

    event PrivateFeeRegistryUpdated(ProtocolFeeRegistry newRegistry);
}
