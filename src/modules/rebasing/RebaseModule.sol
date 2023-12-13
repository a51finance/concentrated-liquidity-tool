// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { AccessControl } from "../../base/AccessControl.sol";
import { ModeTicksCalculation } from "../../base/ModeTicksCalculation.sol";

import { ICLTBase } from "../../interfaces/ICLTBase.sol";
import { IRebaseStrategy } from "../../interfaces/modules/IRebaseStrategy.sol";

/// @title A51 Finance Autonomus Liquidity Provision Rebase Module Contract
/// @author undefined_0x
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract RebaseModule is ModeTicksCalculation, AccessControl, IRebaseStrategy, ReentrancyGuard {
    ICLTBase _cltBase;

    /// @notice Threshold for liquidity consideration
    uint256 public liquidityThreshold = 1e3;

    // 0xca2ac00817703c8a34fa4f786a4f8f1f1eb57801f5369ebb12f510342c03f53b
    bytes32 public constant PRICE_PREFERENCE = keccak256("PRICE_PREFERENCE");
    // 0x697d458f1054678eeb971e50a66090683c55cfb1cab904d3050bdfe6ab249893
    bytes32 public constant REBASE_INACTIVITY = keccak256("REBASE_INACTIVITY");

    /// @notice Constructs the RebaseModule with the provided parameters.
    /// @param _governance Address of the owner.
    /// @param _baseContractAddress Address of the base contract.
    constructor(address _governance, address _baseContractAddress) AccessControl(_governance) {
        _cltBase = ICLTBase(payable(_baseContractAddress));
    }

    /// @notice Executes given strategies.
    /// @dev Can only be called by the operator.
    /// @param strategyIDs Array of strategy IDs to be executed.
    /// @notice Executes given strategies.
    /// @dev Can only be called by the operator.
    /// @param strategyIDs Array of strategy IDs to be executed.
    function executeStrategies(bytes32[] calldata strategyIDs) external nonReentrant {
        checkStrategiesArray(strategyIDs);
        ExecutableStrategiesData[] memory _queue = checkAndProcessStrategies(strategyIDs);

        uint256 queueLength = _queue.length;
        for (uint256 i = 0; i < queueLength; i++) {
            uint256 rebaseCount;
            bool hasRebaseInactivity = false;
            ICLTBase.ShiftLiquidityParams memory params;
            (ICLTBase.StrategyKey memory key,,, bytes memory actionStatus,,,,,) =
                _cltBase.strategies(_queue[i].strategyID);

            if (_queue[i].actionNames[0] == REBASE_INACTIVITY || _queue[i].actionNames[1] == REBASE_INACTIVITY) {
                hasRebaseInactivity = true;
                actionStatus.length > 0 ? rebaseCount = abi.decode(actionStatus, (uint256)) : rebaseCount = 0;
            }

            params.strategyId = _queue[i].strategyID;
            params.shouldMint = true;
            params.swapAmount = 0;

            uint256 queueActionNames = _queue[i].actionNames.length;
            for (uint256 j = 0; j < queueActionNames; j++) {
                if (_queue[i].actionNames[j] == bytes32(0) || _queue[i].actionNames[j] == REBASE_INACTIVITY) {
                    continue;
                }

                (int24 tickLower, int24 tickUpper) = getTicksForMode(key, _queue[i].mode);

                key.tickLower = tickLower;
                key.tickUpper = tickUpper;
                params.key = key;
                params.moduleStatus = hasRebaseInactivity ? abi.encode(uint256(++rebaseCount)) : actionStatus;

                _cltBase.shiftLiquidity(params);
            }
        }
    }

    function executeStrategy(ExectuteStrategyParams calldata executeParams) external nonReentrant {
        (ICLTBase.StrategyKey memory key, address strategyOwner,, bytes memory actionStatus,,,,,) =
            _cltBase.strategies(executeParams.strategyID);

        if (strategyOwner == address(0)) revert StrategyIdDonotExist(executeParams.strategyID);
        if (strategyOwner != msg.sender) revert InvalidCaller();

        key.tickLower = executeParams.tickLower;
        key.tickUpper = executeParams.tickUpper;

        ICLTBase.ShiftLiquidityParams memory params;
        params.key = key;
        params.strategyId = executeParams.strategyID;
        params.shouldMint = executeParams.shouldMint;
        params.zeroForOne = executeParams.zeroForOne;
        params.swapAmount = executeParams.swapAmount;
        params.moduleStatus = actionStatus;

        _cltBase.shiftLiquidity(params);
    }

    /// @notice Computes ticks for a given mode.
    /// @dev Logic to adjust the ticks based on mode.
    /// @param key Strategy key.
    /// @param mode Mode to calculate ticks.
    /// @return tickLower and tickUpper values.
    function getTicksForMode(
        ICLTBase.StrategyKey memory key,
        uint256 mode
    )
        internal
        view
        returns (int24 tickLower, int24 tickUpper)
    {
        if (mode == 1) {
            (tickLower, tickUpper) = shiftLeft(key);
        } else if (mode == 2) {
            (tickLower, tickUpper) = shiftRight(key);
        } else if (mode == 3) {
            (tickLower, tickUpper) = shiftBothSide(key);
        }
        return (tickLower, tickUpper);
    }

    /// @notice Checks and processes strategies based on their validity.
    /// @dev Returns an array of valid strategies.
    /// @param strategyIDs Array of strategy IDs to check and process.
    /// @return ExecutableStrategiesData[] array containing valid strategies.
    function checkAndProcessStrategies(bytes32[] memory strategyIDs)
        internal
        returns (ExecutableStrategiesData[] memory)
    {
        ExecutableStrategiesData[] memory _queue = new ExecutableStrategiesData[](strategyIDs.length);
        uint256 validEntries = 0;
        uint256 strategyIdsLength = strategyIDs.length;

        for (uint256 i = 0; i < strategyIdsLength; i++) {
            ExecutableStrategiesData memory data = getStrategyData(strategyIDs[i]);
            if (data.strategyID != bytes32(0) && data.mode != 0) {
                _queue[validEntries++] = data;
            }
        }

        return _queue;
    }

    // /// @notice Retrieves strategy data based on strategy ID.
    /// @param strategyId The Data of the strategy to retrieve.
    /// @return ExecutableStrategiesData representing the retrieved strategy.
    function getStrategyData(bytes32 strategyId) internal returns (ExecutableStrategiesData memory) {
        (
            ICLTBase.StrategyKey memory key,
            ,
            bytes memory actionsData,
            bytes memory actionStatus,
            ,
            ,
            ,
            ,
            ICLTBase.Account memory account
        ) = _cltBase.strategies(strategyId);

        if (account.totalShares <= liquidityThreshold) {
            return ExecutableStrategiesData(bytes32(0), uint256(0), [bytes32(0), bytes32(0)]);
        }

        ICLTBase.PositionActions memory strategyActionsData = abi.decode(actionsData, (ICLTBase.PositionActions));

        uint256 actionDataLength = strategyActionsData.rebaseStrategy.length;
        for (uint256 i = 0; i < actionDataLength; i++) {
            if (
                strategyActionsData.rebaseStrategy[i].actionName == REBASE_INACTIVITY
                    && !_checkRebaseInactivityStrategies(strategyActionsData.rebaseStrategy[i], actionStatus)
            ) {
                return ExecutableStrategiesData(bytes32(0), uint256(0), [bytes32(0), bytes32(0)]);
            }
        }

        ExecutableStrategiesData memory executableStrategiesData;
        uint256 count = 0;

        for (uint256 i = 0; i < actionDataLength; i++) {
            ICLTBase.StrategyPayload memory rebaseAction = strategyActionsData.rebaseStrategy[i];
            if (shouldAddToQueue(rebaseAction, key, strategyActionsData.mode)) {
                executableStrategiesData.actionNames[count++] = rebaseAction.actionName;
            }
        }

        if (count == 0) {
            return ExecutableStrategiesData(bytes32(0), uint256(0), [bytes32(0), bytes32(0)]);
        }

        executableStrategiesData.mode = strategyActionsData.mode;
        executableStrategiesData.strategyID = strategyId;
        return executableStrategiesData;
    }

    /// @notice Determines if a strategy should be added to the queue.
    /// @dev Checks the preference and other strategy details.
    /// @param rebaseAction  Data related to strategy actions.
    /// @param key Strategy key.
    /// @return bool indicating whether the strategy should be added to the queue.
    function shouldAddToQueue(
        ICLTBase.StrategyPayload memory rebaseAction,
        ICLTBase.StrategyKey memory key,
        uint256 mode
    )
        internal
        view
        returns (bool)
    {
        if (rebaseAction.actionName == PRICE_PREFERENCE) {
            return _checkRebasePreferenceStrategies(key, rebaseAction.data, mode);
        } else if (rebaseAction.actionName == REBASE_INACTIVITY) {
            return true;
        }

        return false;
    }

    /// @notice Checks if rebase preference strategies are satisfied for the given key and action data.
    /// @param key The strategy key to be checked.
    /// @param actionsData The actions data that includes the rebase strategy data.
    /// @return true if the conditions are met, false otherwise.
    function _checkRebasePreferenceStrategies(
        ICLTBase.StrategyKey memory key,
        bytes memory actionsData,
        uint256 mode
    )
        internal
        view
        returns (bool)
    {
        (int24 lowerPreferenceDiff, int24 upperPreferenceDiff) = abi.decode(actionsData, (int24, int24));

        (int24 lowerPreferenceTick, int24 upperPreferenceTick) =
            _getPreferenceTicks(key, lowerPreferenceDiff, upperPreferenceDiff);
        int24 tick = getTwap(key.pool);

        if (mode == 2 && tick > key.tickUpper || mode == 1 && tick < key.tickLower || mode == 3) {
            if (tick < lowerPreferenceTick || tick > upperPreferenceTick) {
                return true;
            }
        }
        return false;
    }

    /// @notice Checks if the rebase inactivity strategies are satisfied.
    /// @param strategyDetail The actions data that includes the rebase strategy data.
    /// @param actionStatus The status of the action.
    /// @return true if the conditions are met, false otherwise.
    function _checkRebaseInactivityStrategies(
        ICLTBase.StrategyPayload memory strategyDetail,
        bytes memory actionStatus
    )
        internal
        pure
        returns (bool)
    {
        uint256 preferredInActivity = abi.decode(strategyDetail.data, (uint256));
        if (actionStatus.length > 0) {
            uint256 rebaseCount = abi.decode(actionStatus, (uint256));
            if (rebaseCount > 0 && preferredInActivity == rebaseCount) {
                return false;
            }
        }
        return true;
    }

    function checkInputData(ICLTBase.StrategyPayload memory actionsData) external pure override returns (bool) {
        bool hasDiffPreference = actionsData.actionName == PRICE_PREFERENCE;
        bool hasInActivity = actionsData.actionName == REBASE_INACTIVITY;

        // need to check here whether the preference ticks are outside of range
        if (hasDiffPreference && isNonZero(actionsData.data)) {
            (int24 lowerPreferenceDiff, int24 upperPreferenceDiff) = abi.decode(actionsData.data, (int24, int24));
            if (lowerPreferenceDiff <= 0 || upperPreferenceDiff <= 0) {
                revert InvalidPricePreferenceDifference();
            }
            return true;
        }

        if (hasInActivity) {
            //   check needs to be added on frontend so that rebase inactivity cannot be seleted independently
            uint256 preferredInActivity = abi.decode(actionsData.data, (uint256));
            if (preferredInActivity == 0) {
                revert RebaseInactivityCannotBeZero();
            }
            return true;
        }
        revert RebaseStrategyDataCannotBeZero();
    }

    /// @notice Checks the bytes value is non zero or not.
    /// @param data bytes value to be checked.
    /// @return true if the value is nonzero.
    function isNonZero(bytes memory data) internal pure returns (bool) {
        uint256 dataLength = data.length;
        for (uint256 i = 0; i < dataLength; i++) {
            if (data[i] != bytes1(0)) {
                return true;
            }
        }
        return false;
    }

    /// @notice Checks the strategies array for validity.
    /// @param data An array of strategy IDs.
    /// @return true if the strategies array is valid.
    function checkStrategiesArray(bytes32[] memory data) internal returns (bool) {
        // this function has a comlexity of O(n^2).
        if (data.length == 0) {
            revert StrategyIdsCannotBeEmpty();
        }
        // check 0 strategyId
        uint256 dataLength = data.length;
        for (uint256 i = 0; i < dataLength; i++) {
            (, address strategyOwner,,,,,,,) = _cltBase.strategies(data[i]);
            if (data[i] == bytes32(0) || strategyOwner == address(0)) {
                revert InvalidStrategyId(data[i]);
            }

            // check duplicacy
            for (uint256 j = i + 1; j < data.length; j++) {
                if (data[i] == data[j]) {
                    revert DuplicateStrategyId(data[i]);
                }
            }
        }

        return true;
    }

    ///@notice Calculates the preference ticks based on the strategy key and the given preference differences.
    /// @dev  This function adjusts the given tick bounds (both lower and upper) based on a preference difference. The
    /// preference differences indicate by how much the ticks should be moved.
    /// @param _key The strategy key.
    /// @param lowerPreferenceDiff The lower preference difference.
    /// @param upperPreferenceDiff The upper preference difference.
    /// @return lowerPreferenceTick The calculated lower preference tick.
    /// @return upperPreferenceTick The calculated upper preference tick.
    function _getPreferenceTicks(
        ICLTBase.StrategyKey memory _key,
        int24 lowerPreferenceDiff,
        int24 upperPreferenceDiff
    )
        internal
        pure
        returns (int24 lowerPreferenceTick, int24 upperPreferenceTick)
    {
        lowerPreferenceTick = _key.tickLower - lowerPreferenceDiff;
        upperPreferenceTick = _key.tickUpper + upperPreferenceDiff;
    }

    /// @notice Updates the liquidity threshold.
    /// @dev Reverts if the new threshold is less than or equal to zero.
    /// @param _newThreshold The new liquidity threshold value.
    function updateLiquidityThreshold(uint256 _newThreshold) external onlyOperator {
        if (_newThreshold <= 0) {
            revert InvalidThreshold();
        }
        liquidityThreshold = _newThreshold;
    }
}
