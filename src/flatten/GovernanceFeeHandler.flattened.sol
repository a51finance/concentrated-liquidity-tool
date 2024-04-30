// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15 >=0.5.0 >=0.8.0;

// lib/solmate/src/auth/Owned.sol

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

// src/interfaces/IGovernanceFeeHandler.sol

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

// src/libraries/Constants.sol

library Constants {
    uint256 public constant WAD = 1e18;

    uint256 public constant MIN_INITIAL_SHARES = 1e3;

    uint256 public constant MAX_MANAGEMENT_FEE = 2e17;

    uint256 public constant MAX_PERFORMANCE_FEE = 2e17;

    uint256 public constant MAX_PROTCOL_MANAGEMENT_FEE = 2e17;

    uint256 public constant MAX_PROTCOL_PERFORMANCE_FEE = 2e17;

    uint256 public constant MAX_AUTOMATION_FEE = 2e17;

    uint256 public constant MAX_STRATEGY_CREATION_FEE = 5e17;

    uint128 public constant MAX_UINT128 = type(uint128).max;

    // keccak256("MODE")
    bytes32 public constant MODE = 0x25d202ee31c346b8c1099dc1a469d77ca5ac14ed43336c881902290b83e0a13a;

    // keccak256("EXIT_STRATEGY")
    bytes32 public constant EXIT_STRATEGY = 0xf36a697ed62dd2d982c1910275ee6172360bf72c4dc9f3b10f2d9c700666e227;

    // keccak256("REBASE_STRATEGY")
    bytes32 public constant REBASE_STRATEGY = 0x5eea0aea3d82798e316d046946dbce75c9d5995b956b9e60624a080c7f56f204;

    // keccak256("LIQUIDITY_DISTRIBUTION")
    bytes32 public constant LIQUIDITY_DISTRIBUTION = 0xeabe6f62bd74d002b0267a6aaacb5212bb162f4f87ee1c4a80ac0d2698f8a505;
}

// src/GovernanceFeeHandler.sol

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
