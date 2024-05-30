//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

interface IGovernanceFeeHandler {
    error StrategyFeeLimitExceed();
    error ManagementFeeLimitExceed();
    error PerformanceFeeLimitExceed();
    error LPAutomationFeeLimitExceed();

    /// @param lpAutomationFee The value of fee applied for automation of strategy
    /// @param strategyCreationFee The value of fee applied for creation of new strategy
    /// @param protcolFeeOnManagement  The value of fee applied on strategiest earned fee on managment of strategy
    /// @param protcolFeeOnPerformance The value of fee applied on strategiest earned fee on performance of strategy
    struct ProtocolFeeRegistry {
        uint256 lpAutomationFee;
        uint256 strategyCreationFee;
        uint256 protcolFeeOnManagement;
        uint256 protcolFeeOnPerformance;
    }

    /// @notice Returns the protocol fee value
    /// @param isPrivate Bool value weather strategy is private or public
    function getGovernanceFee(bool isPrivate)
        external
        view
        returns (
            uint256 lpAutomationFee,
            uint256 strategyCreationFee,
            uint256 protcolFeeOnManagement,
            uint256 protcolFeeOnPerformance
        );

    /// @notice Updates the protocol fee value for public strategy
    function setPublicFeeRegistry(ProtocolFeeRegistry calldata newPublicStrategyFeeRegistry) external;

    /// @notice Updates the protocol fee value for private strategy
    function setPrivateFeeRegistry(ProtocolFeeRegistry calldata newPrivateStrategyFeeRegistry) external;

    /// @notice Emitted when the protocol fee for public strategy has been updated
    event PublicFeeRegistryUpdated(ProtocolFeeRegistry newRegistry);

    /// @notice Emitted when the protocol fee for private strategy has been updated
    event PrivateFeeRegistryUpdated(ProtocolFeeRegistry newRegistry);
}
