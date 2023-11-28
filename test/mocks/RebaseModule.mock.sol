// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

// Importing foundational and interfaced contracts
import { console } from "forge-std/console.sol";
import "../../src/base/ModeTicksCalculation.sol";
import "../../src/base/AccessControl.sol";
import "../../src/interfaces/modules/IPreference.sol";
import "../../src/interfaces/ICLTBase.sol";
import "forge-std/console.sol";

/// @title A51 Finance Autonomus Liquidity Provision Rebase Module Contract
/// @author undefined_0x
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract RebaseModuleMock is ModeTicksCalculation, AccessControl, IPreference {
    ICLTBase _cltBase;

    /// @notice Threshold for liquidity consideration
    uint256 public liquidityThreshold = 1e3;
    /// @notice Maximum allowable time period
    uint256 public constant MAX_TIME_PERIOD = 31_536_000;
    /// @notice Minimum allowable time period
    uint256 public constant MIN_TIME_PERIOD = 1;

    // 0xca2ac00817703c8a34fa4f786a4f8f1f1eb57801f5369ebb12f510342c03f53b
    bytes32 public constant PRICE_PREFERENCE = keccak256("PRICE_PREFERENCE");
    // 0x4036d2cde3df45671689d4979c1a0416dd81c5761f9d35cce34ae9a59728ccb2
    bytes32 public constant TIME_PREFERENCE = keccak256("TIME_PREFERENCE");
    // 0x697d458f1054678eeb971e50a66090683c55cfb1cab904d3050bdfe6ab249893
    bytes32 public constant REBASE_INACTIVITY = keccak256("REBASE_INACTIVITY");

    /// @notice Constructs the RebaseModule with the provided parameters.
    /// @param _owner Address of the owner.
    /// @param _baseContractAddress Address of the base contract.
    constructor(address _owner, address _baseContractAddress) AccessControl(_owner) {
        _cltBase = ICLTBase(payable(_baseContractAddress));
    }

    /// @notice Executes given strategies.
    /// @dev Can only be called by the operator.
    /// @param strategyIDs Array of strategy IDs to be executed.
    /// @notice Executes given strategies.
    /// @dev Can only be called by the operator.
    /// @param strategyIDs Array of strategy IDs to be executed.
    function executeStrategies(StrategyInputData[] memory strategyIDs) external onlyOperator {
        checkStrategiesArray(strategyIDs);
        ExecutableStrategiesData[] memory _queue = checkAndProcessStrategies(strategyIDs);

        for (uint256 i = 0; i < _queue.length; i++) {
            uint256 rebaseCount;
            bool hasRebaseInactivity = false;
            ICLTBase.ShiftLiquidityParams memory params;
            (ICLTBase.StrategyKey memory key,,, bytes memory actionStatus,,,,,,,) =
                _cltBase.strategies(_queue[i].strategyID);

            if (
                _queue[i].actionNames[0] == REBASE_INACTIVITY || _queue[i].actionNames[1] == REBASE_INACTIVITY
                    || _queue[i].actionNames[2] == REBASE_INACTIVITY
            ) {
                hasRebaseInactivity = true;
                actionStatus.length > 0 ? rebaseCount = abi.decode(actionStatus, (uint256)) : rebaseCount = 0;
            }

            params.strategyId = _queue[i].strategyID;
            params.shouldMint = false;
            params.swapAmount = 0;

            for (uint256 j = 0; j < _queue[i].actionNames.length; j++) {
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
        emit Executed(_queue);
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
        public
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
    function checkAndProcessStrategies(StrategyInputData[] memory strategyIDs)
        public
        returns (ExecutableStrategiesData[] memory)
    {
        ExecutableStrategiesData[] memory _queue = new ExecutableStrategiesData[](strategyIDs.length);
        uint256 validEntries = 0;

        for (uint256 i = 0; i < strategyIDs.length; i++) {
            ExecutableStrategiesData memory data = getStrategyData(strategyIDs[i]);
            if (data.strategyID != bytes32(0) && data.mode != 0) {
                _queue[validEntries++] = data;
            }
        }

        return _queue;
    }

    // /// @notice Retrieves strategy data based on strategy ID.
    /// @param strategyData The Data of the strategy to retrieve.
    /// @return ExecutableStrategiesData representing the retrieved strategy.
    function getStrategyData(StrategyInputData memory strategyData) public returns (ExecutableStrategiesData memory) {
        (
            ICLTBase.StrategyKey memory key,
            ,
            bytes memory actionsData,
            bytes memory actionStatus,
            ,
            ,
            ,
            uint256 totalShares,
            ,
            ,
        ) = _cltBase.strategies(strategyData.strategyID);

        if (totalShares <= liquidityThreshold) {
            return ExecutableStrategiesData(bytes32(0), uint256(0), [bytes32(0), bytes32(0), bytes32(0)]);
        }

        ICLTBase.PositionActions memory strategyActionsData = abi.decode(actionsData, (ICLTBase.PositionActions));

        for (uint256 i = 0; i < strategyActionsData.rebaseStrategy.length; i++) {
            if (
                strategyActionsData.rebaseStrategy[i].actionName == REBASE_INACTIVITY
                    && !_checkRebaseInactivityStrategies(strategyActionsData.rebaseStrategy[i], actionStatus)
            ) {
                return ExecutableStrategiesData(bytes32(0), uint256(0), [bytes32(0), bytes32(0), bytes32(0)]);
            }
        }

        ExecutableStrategiesData memory executableStrategiesData;
        uint256 count = 0;

        for (uint256 i = 0; i < strategyActionsData.rebaseStrategy.length; i++) {
            ICLTBase.StrategyPayload memory rebaseAction = strategyActionsData.rebaseStrategy[i];
            if (shouldAddToQueue(rebaseAction, key, strategyData.rebaseOptions, strategyActionsData.mode)) {
                executableStrategiesData.actionNames[count++] = rebaseAction.actionName;
            }
        }

        if (count == 0) {
            return ExecutableStrategiesData(bytes32(0), uint256(0), [bytes32(0), bytes32(0), bytes32(0)]);
        }

        executableStrategiesData.mode = strategyActionsData.mode;
        executableStrategiesData.strategyID = strategyData.strategyID;
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
        bytes memory rebaseOptions,
        uint256 mode
    )
        public
        view
        returns (bool)
    {
        if (rebaseAction.actionName == PRICE_PREFERENCE) {
            return _checkRebasePreferenceStrategies(key, rebaseAction.data, mode);
        } else if (rebaseAction.actionName == TIME_PREFERENCE) {
            return _checkRebaseTimePreferenceStrategies(rebaseAction.data, rebaseOptions);
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
        public
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

    /// @notice Checks if the rebase time preference strategies are satisfied.
    /// @param actionsData The actions data that includes the rebase strategy data.
    /// @return true if the conditions are met.
    function _checkRebaseTimePreferenceStrategies(
        bytes memory actionsData,
        bytes memory rebaseOptions
    )
        public
        view
        returns (bool)
    {
        if (rebaseOptions.length > 0) {
            uint256 timePreference = abi.decode(actionsData, (uint256));
            uint256 startTime = abi.decode(rebaseOptions, (uint256));
            uint256 maxTime = startTime + MAX_TIME_PERIOD;
            if (startTime + timePreference < block.timestamp && block.timestamp < maxTime) {
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
        public
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
        bool hasTimePreference = actionsData.actionName == TIME_PREFERENCE;
        bool hasInActivity = actionsData.actionName == REBASE_INACTIVITY;

        // need to check here whether the preference ticks are outside of range
        if (hasDiffPreference && isNonZero(actionsData.data)) {
            (int24 lowerPreferenceDiff, int24 upperPreferenceDiff) = abi.decode(actionsData.data, (int24, int24));
            if (lowerPreferenceDiff <= 0 || upperPreferenceDiff <= 0) {
                revert InvalidPricePreferenceDifference();
            }
            return true;
        }

        if (hasTimePreference && isNonZero(actionsData.data)) {
            // In seconds
            uint256 timePreference = abi.decode(actionsData.data, (uint256));
            if (timePreference < MIN_TIME_PERIOD || timePreference >= MAX_TIME_PERIOD) {
                revert InvalidTimePreference();
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
    function isNonZero(bytes memory data) public pure returns (bool) {
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
    function checkStrategiesArray(StrategyInputData[] memory data) public returns (bool) {
        // this function has a comlexity of O(n^2).
        console.log(data.length);
        if (data.length == 0) {
            revert StrategyIdsCannotBeEmpty();
        }
        // check 0 strategyId
        for (uint256 i = 0; i < data.length; i++) {
            (, address strategyOwner,,,,,,,,,) = _cltBase.strategies(data[i].strategyID);
            if (data[i].strategyID == bytes32(0) || strategyOwner == address(0)) {
                // revert StrategyIdCannotBeZero();
                revert InvalidStrategyId(data[i].strategyID);
            }

            // check duplicacy
            for (uint256 j = i + 1; j < data.length; j++) {
                if (data[i].strategyID == data[j].strategyID) {
                    revert DuplicateStrategyId(data[i].strategyID);
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
        public
        pure
        returns (int24 lowerPreferenceTick, int24 upperPreferenceTick)
    {
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
    function _floor(int24 tick, int24 tickSpacing) public pure returns (int24) {
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
