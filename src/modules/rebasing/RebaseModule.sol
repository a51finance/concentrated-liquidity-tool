// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

// Importing foundational and interfaced contracts
import "../../base/ModeTicksCalculation.sol";
import "../../base/AccessControl.sol";
import "../../interfaces/modules/IPreference.sol";
import "../../interfaces/ICLTBase.sol";

/// @title A51 Finance Autonomus Liquidity Provision Rebase Module Contract
/// @author undefined_0x
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract RebaseModule is ModeTicksCalculation, AccessControl, IPreference {
    /// @notice Threshold for liquidity consideration
    uint256 public liquidityThreshold = 1e3;
    /// @notice Maximum allowable time period
    uint256 public maxTimePeriod;

    bytes32 public constant PRICE_PREFERENCE = keccak256("PRICE_PREFERENCE");
    bytes32 public constant TIME_PREFERENCE = keccak256("TIME_PREFERENCE");
    bytes32 public constant REBASE_INACTIVITY = keccak256("REBASE_INACTIVITY");

    ICLTBase _cltBase; // Instance of the ICLTBase interface

    /// @notice Constructs the RebaseModule with the provided parameters.
    /// @param _owner Address of the owner.
    /// @param _baseContractAddress Address of the base contract.
    constructor(address _owner, address _baseContractAddress) AccessControl(_owner) {
        _cltBase = ICLTBase(payable(_baseContractAddress));
        maxTimePeriod = 31_536_000; // Represents seconds in a year.
    }

    /// @notice Executes given strategies.
    /// @dev Can only be called by the operator.
    /// @param strategyIDs Array of strategy IDs to be executed.
    function executeStrategies(bytes32[] memory strategyIDs) external onlyOperator {
        checkStrategiesArray(strategyIDs);

        ExecutableStrategiesData[] memory _queue = checkAndProcessStrategies(strategyIDs);

        for (uint256 i = 0; i < _queue.length; i++) {
            ShiftLiquidityParams memory params;
            (StrategyKey memory key,, bytes memory actionStatus,,,,,,,) = _cltBase.strategies(_queue[i].strategyID);
            uint256 rebaseCount = abi.decode(actionStatus, (uint256));

            params.strategyId = _queue[i].strategyID;
            params.shouldMint = false;
            params.swapAmount = 0;

            for (uint256 j = 0; j < _queue[i].actionNames.length; j++) {
                (int24 tickLower, int24 tickUpper) = getTicksForMode(key, _queue[i].mode);
                key.tickLower = tickLower;
                key.tickUpper = tickUpper;
                params.key = key;
                params.moduleStatus =
                    _queue[i].actionNames[j] == REBASE_INACTIVITY ? abi.encode(uint256(++rebaseCount)) : actionStatus;
                _cltBase.shiftLiquidity(params);
            }
        }

        emit Executed(_queue);
    }

    /// @notice Computes ticks for a given mode.
    /// @dev Logic to adjust the ticks based on mode.
    /// @param key Strategy key.
    /// @param mode Mode to calculate ticks.
    /// @return tickLower and tickUpper values.

    function getTicksForMode(
        StrategyKey memory key,
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

        for (uint256 i = 0; i < strategyIDs.length; i++) {
            ExecutableStrategiesData memory data = getStrategyData(strategyIDs[i]);
            if (data.strategyID != bytes32(0)) {
                _queue[validEntries++] = data;
            }
        }
        return _queue;
    }

    // /// @notice Retrieves strategy data based on strategy ID.
    /// @param strategyID The ID of the strategy to retrieve.
    /// @return ExecutableStrategiesData representing the retrieved strategy.
    function getStrategyData(bytes32 strategyID) internal returns (ExecutableStrategiesData memory) {
        (StrategyKey memory key, bytes memory actionsData, bytes memory actionStatus,,,, uint256 totalShares,,,) =
            _cltBase.strategies(strategyID);

        if (totalShares <= liquidityThreshold) {
            return ExecutableStrategiesData(bytes32(0), uint256(0), [bytes32(0), bytes32(0), bytes32(0)]);
        }

        ActionDetails memory strategyActionsData = abi.decode(actionsData, (ActionDetails));

        ExecutableStrategiesData memory executableStrategiesData;
        uint256 count = 0;
        for (uint256 i = 0; i < strategyActionsData.rebaseStrategy.length; i++) {
            StrategyDetail memory rebaseAction = strategyActionsData.rebaseStrategy[i];

            // issue here regarding the findings of REBASE_INACTIVITY
            if (_checkRebaseInactivityStrategies(rebaseAction, actionStatus) && shouldAddToQueue(rebaseAction, key)) {
                executableStrategiesData.actionNames[count++] = rebaseAction.actionName;
            }
        }

        if (count == 0) {
            return ExecutableStrategiesData(bytes32(0), uint256(0), [bytes32(0), bytes32(0), bytes32(0)]);
        }

        executableStrategiesData.mode = strategyActionsData.mode;
        executableStrategiesData.strategyID = strategyID;
        return executableStrategiesData;
    }

    /// @notice Determines if a strategy should be added to the queue.
    /// @dev Checks the preference and other strategy details.
    /// @param rebaseAction  Data related to strategy actions.
    /// @param key Strategy key.
    /// @return bool indicating whether the strategy should be added to the queue.
    function shouldAddToQueue(
        StrategyDetail memory rebaseAction,
        StrategyKey memory key
    )
        internal
        view
        returns (bool)
    {
        if (rebaseAction.actionName == PRICE_PREFERENCE) {
            return _checkRebasePreferenceStrategies(key, rebaseAction.data);
        } else if (rebaseAction.actionName == TIME_PREFERENCE) {
            return _checkRebaseTimePreferenceStrategies(rebaseAction.data);
        }
        return false;
    }

    /// @notice Checks if rebase preference strategies are satisfied for the given key and action data.
    /// @param key The strategy key to be checked.
    /// @param actionsData The actions data that includes the rebase strategy data.
    /// @return true if the conditions are met, false otherwise.
    function _checkRebasePreferenceStrategies(
        StrategyKey memory key,
        bytes memory actionsData
    )
        internal
        view
        returns (bool)
    {
        (int24 lowerPreferenceDiff, int24 upperPreferenceDiff) = abi.decode(actionsData, (int24, int24));

        (int24 lowerPreferenceTick, int24 upperPreferenceTick) =
            _getPreferenceTicks(key, lowerPreferenceDiff, upperPreferenceDiff);

        int24 tick = getTwap(key.pool);

        if (tick < lowerPreferenceTick || tick > upperPreferenceTick) {
            return true;
        }
        return false;
    }

    /// @notice Checks if the rebase time preference strategies are satisfied.
    /// @param actionsData The actions data that includes the rebase strategy data.
    /// @return true if the conditions are met.
    function _checkRebaseTimePreferenceStrategies(bytes memory actionsData) internal view returns (bool) {
        uint256 timePreference = abi.decode(actionsData, (uint256));
        if (timePreference < block.timestamp || timePreference >= maxTimePeriod || timePreference == 0) {
            revert TimePreferenceConstraint();
        }
        return true;
    }

    /// @notice Checks if the rebase inactivity strategies are satisfied.
    /// @param strategyDetail The actions data that includes the rebase strategy data.
    /// @param actionStatus The status of the action.
    /// @return true if the conditions are met, false otherwise.
    function _checkRebaseInactivityStrategies(
        StrategyDetail memory strategyDetail,
        bytes memory actionStatus
    )
        internal
        pure
        returns (bool)
    {
        // actionsData.rebaseStrategyData[2] can generate error ac one rebase action is selected
        uint256 preferredInActivity = abi.decode(strategyDetail.data, (uint256));
        uint256 rebaseCount = abi.decode(actionStatus, (uint256));
        if (rebaseCount > 0 && preferredInActivity == rebaseCount) {
            return false;
        }

        return true;
    }

    function checkInputData(StrategyDetail memory actionsData) external view returns (bool) {
        bool hasDiffPreference = actionsData.actionName == PRICE_PREFERENCE;
        bool hasTimePreference = actionsData.actionName == TIME_PREFERENCE;
        bool hasInActivity = actionsData.actionName == REBASE_INACTIVITY;

        if (hasDiffPreference && isNonZero(actionsData.data)) {
            (int24 lowerPreferenceDiff, int24 upperPreferenceDiff) = abi.decode(actionsData.data, (int24, int24));
            if (lowerPreferenceDiff <= 0 || upperPreferenceDiff <= 0) {
                revert InvalidPreferenceDifference();
            }
            return true;
        }

        if (hasTimePreference && isNonZero(actionsData.data)) {
            uint256 timePreference = abi.decode(actionsData.data, (uint256));
            if (timePreference <= block.timestamp || timePreference >= maxTimePeriod || timePreference == 0) {
                revert InvalidTimePreference();
            }
            return true;
        }

        if (hasInActivity && isNonZero(actionsData.data)) {
            if (hasDiffPreference && hasTimePreference) {
                revert OnlyRebaseInactivityCannotBeSelected();
            }
            uint256 preferredInActivity = abi.decode(actionsData.data, (uint256));
            if (preferredInActivity == 0) {
                revert RebaseInactivityCannotBeZero();
            }
            return true;
        }
        return false;
    }

    /// @notice Checks the bytes value is non zero or not.
    /// @param data bytes value to be checked.
    /// @return true if the value is nonzero.
    function isNonZero(bytes memory data) internal pure returns (bool) {
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] != bytes1(0)) {
                return true;
            }
        }
        return false;
    }

    /// @notice Checks the strategies array for validity.
    /// @param data An array of strategy IDs.
    /// @return true if the strategies array is valid.
    function checkStrategiesArray(bytes32[] memory data) internal pure returns (bool) {
        // this function has a comlexity of O(n^2).
        if (data.length == 0) {
            revert StrategyIdsCannotBeEmpty();
        }
        // check 0 strategyId
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == bytes32(0)) {
                revert StrategyIdCannotBeZero();
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
        StrategyKey memory _key,
        int24 lowerPreferenceDiff,
        int24 upperPreferenceDiff
    )
        internal
        pure
        returns (int24 lowerPreferenceTick, int24 upperPreferenceTick)
    {
        // need to check alot of scenarios for this logic
        lowerPreferenceTick = _key.tickLower - lowerPreferenceDiff;
        upperPreferenceTick = _key.tickUpper + upperPreferenceDiff;
    }

    /// @notice Floors the given tick value based on the specified tick spacing.
    /// @dev The flooring logic ensures that tick values are compliant with the tick spacing set by the pool.
    /// This is especially necessary for protocols like Uniswap V3 where positions are defined by ticks and the ticks
    /// have a specific spacing. If a tick is not an exact multiple of the spacing, this function helps to floor it
    /// to the nearest lower multiple.
    /// @param tick The tick value to be floored.
    /// @param tickSpacing The spacing value for flooring.
    /// @return The floored tick value.
    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
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
