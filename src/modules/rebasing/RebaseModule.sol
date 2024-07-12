// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { PositionKey } from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import { AccessControl } from "../../base/AccessControl.sol";
import { ModeTicksCalculation } from "../../base/ModeTicksCalculation.sol";
import { ActiveTicksCalculation } from "../../base/ActiveTicksCalculation.sol";

import { ICLTBase } from "../../interfaces/ICLTBase.sol";
import { ICLTTwapQuoter } from "../../interfaces/ICLTTwapQuoter.sol";
import { IRebaseStrategy } from "../../interfaces/modules/IRebaseStrategy.sol";

import { PoolActions } from "../../libraries/PoolActions.sol";

/// @title A51 Finance Autonomous Liquidity Provision Rebase Module Contract
/// @author undefined_0x
/// @notice This contract is part of the A51 Finance platform, focusing on automated liquidity provision and rebalancing
/// strategies. The RebaseModule contract is responsible for validating and verifying the strategies before executing
/// them through CLTBase.
contract RebaseModule is ModeTicksCalculation, ActiveTicksCalculation, AccessControl, IRebaseStrategy {
    /// @notice The address of base contract
    ICLTBase public immutable cltBase;

    /// @notice The address of twap quoter
    ICLTTwapQuoter public twapQuoter;

    /// @notice slippage percentage
    uint160 slippage = 1e5;

    /// @notice Threshold for swaps in manual override
    uint256 public swapsThreshold = 5;

    /// @notice Percentage for swaps in active rebalancing
    uint8 public swapsPecentage = 50;

    // 0xca2ac00817703c8a34fa4f786a4f8f1f1eb57801f5369ebb12f510342c03f53b
    bytes32 public constant PRICE_PREFERENCE = keccak256("PRICE_PREFERENCE");
    // 0x697d458f1054678eeb971e50a66090683c55cfb1cab904d3050bdfe6ab249893
    bytes32 public constant REBASE_INACTIVITY = keccak256("REBASE_INACTIVITY");
    // 0x71b5978b6e44da7015285ded9bf0268792b41f7b24b8326894bf7495311010ea
    bytes32 public constant ACTIVE_REBALANCE = keccak256("ACTIVE_REBALANCE");

    /// @notice Constructs the RebaseModule with the provided parameters.
    /// @param _governance Address of the owner.
    /// @param _baseContractAddress Address of the base contract.
    constructor(address _governance, address _baseContractAddress, address _twapQuoter) AccessControl(_governance) {
        twapQuoter = ICLTTwapQuoter(_twapQuoter);
        cltBase = ICLTBase(payable(_baseContractAddress));
    }

    /// @notice Executes given strategies via bot.
    /// @dev Can be called by any one.
    /// @param strategyIDs Array of strategy IDs to be executed.

    function executeStrategies(bytes32[] calldata strategyIDs) external nonReentrancy {
        checkStrategiesArray(strategyIDs);
        ExecutableStrategiesData[] memory _queue = checkAndProcessStrategies(strategyIDs);
        uint256 queueLength = _queue.length;
        for (uint256 i = 0; i < queueLength; i++) {
            processStrategy(_queue[i]);
        }
    }

    // Internal function to process a single strategy
    function processStrategy(ExecutableStrategiesData memory data) internal {
        (ICLTBase.StrategyKey memory key,,, bytes memory actionStatus,,,,,) = cltBase.strategies(data.strategyID);
        IRebaseStrategy.StrategyProcessingDetails memory details =
            initializeStrategyDetails(actionStatus, data.actionNames);

        ICLTBase.ShiftLiquidityParams memory params;
        params.strategyId = data.strategyID;
        params.shouldMint = true;

        executeStrategyActions(data, key, params, details, actionStatus);
    }

    // Function to initialize details for processing a strategy
    function initializeStrategyDetails(
        bytes memory actionStatus,
        bytes32[3] memory actionNames
    )
        internal
        pure
        returns (IRebaseStrategy.StrategyProcessingDetails memory details)
    {
        details.hasRebaseInactivity = checkRebaseInactivity(actionNames);
        if (details.hasRebaseInactivity && actionStatus.length > 0) {
            (details.rebaseCount,, details.lastUpdateTimeStamp, details.manualSwapsCount) =
                abi.decode(actionStatus, (uint256, bool, uint256, uint256));
        }
        return details;
    }

    // Helper function to check for REBASE_INACTIVITY in action names
    function checkRebaseInactivity(bytes32[3] memory actionNames) internal pure returns (bool) {
        for (uint256 i = 0; i < actionNames.length; i++) {
            if (actionNames[i] == REBASE_INACTIVITY) {
                return true;
            }
        }
        return false;
    }

    // Function to execute actions for a strategy
    function executeStrategyActions(
        ExecutableStrategiesData memory data,
        ICLTBase.StrategyKey memory key,
        ICLTBase.ShiftLiquidityParams memory params,
        IRebaseStrategy.StrategyProcessingDetails memory details,
        bytes memory actionStatus
    )
        internal
    {
        ICLTBase.StrategyKey memory originalKey =
            ICLTBase.StrategyKey({ pool: key.pool, tickLower: key.tickLower, tickUpper: key.tickUpper });

        for (uint256 j = 0; j < data.actionNames.length; j++) {
            if (data.actionNames[j] == bytes32(0) || data.actionNames[j] == REBASE_INACTIVITY) {
                continue;
            }
            // Update key values
            (key.tickLower, key.tickUpper) = getTicksForModeWithActions(key, data.mode, data.actionNames[j]);
            if (data.actionNames[j] == ACTIVE_REBALANCE) {
                (int256 amountToSwap, bool zeroForOne) = _getSwapAmount(data.strategyID, originalKey, key);

                (uint160 sqrtPriceX96,,,,,,) = key.pool.slot0();
                // @audit-info need to rethink this logic
                uint160 exactSqrtPriceImpact = (sqrtPriceX96 * (slippage / 2)) / 1e6;

                params.swapAmount = amountToSwap;
                params.zeroForOne = zeroForOne;

                params.sqrtPriceLimitX96 =
                    zeroForOne ? sqrtPriceX96 - exactSqrtPriceImpact : sqrtPriceX96 + exactSqrtPriceImpact;
            } else if (data.actionNames[j] == PRICE_PREFERENCE) {
                params.swapAmount = 0;
            }

            params.key = key;
            params.moduleStatus = details.hasRebaseInactivity
                ? abi.encode(uint256(++details.rebaseCount), false, details.lastUpdateTimeStamp, details.manualSwapsCount)
                : actionStatus;

            cltBase.shiftLiquidity(params);
        }
    }

    /// @notice Provides functionality for executing and managing strategies manually with customizations.
    /// @dev This function updates strategy parameters, checks for permissions, and triggers liquidity shifts.
    function executeStrategy(ExectuteStrategyParams calldata executeParams) external nonReentrancy {
        (ICLTBase.StrategyKey memory key, address strategyOwner,, bytes memory actionStatus,,,,,) =
            cltBase.strategies(executeParams.strategyID);

        if (strategyOwner == address(0)) revert StrategyIdDonotExist(executeParams.strategyID);
        if (strategyOwner != msg.sender) revert InvalidCaller();

        key.tickLower = executeParams.tickLower;
        key.tickUpper = executeParams.tickUpper;

        bool isExited;
        uint256 rebaseCount;
        uint256 manualSwapsCount;
        uint256 lastUpdateTimeStamp;

        if (swapsThreshold != 0 && executeParams.swapAmount > 0) {
            if (actionStatus.length == 0) {
                lastUpdateTimeStamp = block.timestamp;
                manualSwapsCount = 1;
            } else {
                if (actionStatus.length == 64) {
                    (lastUpdateTimeStamp, manualSwapsCount) = _checkSwapsInADay(0, 0);
                } else {
                    (,, uint256 _lastUpdateTimeStamp, uint256 _manualSwapsCount) =
                        abi.decode(actionStatus, (uint256, bool, uint256, uint256));
                    (lastUpdateTimeStamp, manualSwapsCount) = _checkSwapsInADay(_lastUpdateTimeStamp, _manualSwapsCount);
                }
            }
        }

        ICLTBase.ShiftLiquidityParams memory params;
        params.key = key;
        params.strategyId = executeParams.strategyID;
        params.shouldMint = executeParams.shouldMint;
        params.zeroForOne = executeParams.zeroForOne;
        params.swapAmount = executeParams.swapAmount;
        params.sqrtPriceLimitX96 = executeParams.sqrtPriceLimitX96;

        isExited = !executeParams.shouldMint;

        if (actionStatus.length > 0) {
            if (actionStatus.length == 64) {
                (rebaseCount,) = abi.decode(actionStatus, (uint256, bool));
            } else {
                (rebaseCount,,,) = abi.decode(actionStatus, (uint256, bool, uint256, uint256));
            }
        }

        params.moduleStatus = abi.encode(rebaseCount, isExited, lastUpdateTimeStamp, manualSwapsCount);

        cltBase.shiftLiquidity(params);
    }

    function _getSwapAmount(
        bytes32 strategyId,
        ICLTBase.StrategyKey memory originalKey,
        ICLTBase.StrategyKey memory newKey
    )
        internal
        returns (int256 amountSpecified, bool zeroForOne)
    {
        IRebaseStrategy.SwapAmountsParams memory swapParams;

        // condition-1: getting the assets for completely out of range liquidity
        (,,,, bool isCompound, bool isPrivate,,, ICLTBase.Account memory account) = cltBase.strategies(strategyId);

        (swapParams.amount0Desired, swapParams.amount1Desired) =
            PoolActions.getAmountsForLiquidity(originalKey, account.uniswapLiquidity);

        (, swapParams.strategyFee0, swapParams.strategyFee1) = cltBase.getStrategyReserves(strategyId);

        // remove tax from the balance
        (swapParams.protocolFee0, swapParams.protocolFee1) = ActiveTicksCalculation.getProtocolFeeses(
            isPrivate, swapParams.amount0Desired, swapParams.amount1Desired, cltBase.feeHandler()
        );

        swapParams.amount0Desired += account.balance0 - swapParams.protocolFee0;
        swapParams.amount1Desired += account.balance1 - swapParams.protocolFee1;

        if (isCompound) {
            swapParams.amount0Desired += swapParams.strategyFee0;
            swapParams.amount1Desired += swapParams.strategyFee1;
        }

        if ((account.uniswapLiquidity > 0) && (swapParams.amount0Desired == 0 || swapParams.amount1Desired == 0)) {
            zeroForOne = swapParams.amount0Desired > 0 ? true : false;

            amountSpecified = zeroForOne
                ? int256(FullMath.mulDiv(swapParams.amount0Desired, swapsPecentage, 100))
                : int256(FullMath.mulDiv(swapParams.amount1Desired, swapsPecentage, 100));
            return (amountSpecified, zeroForOne);
        }
        // condition-2: getting the assets for partial out of range liquidity
        else {
            uint128 newliquidity =
                PoolActions.getLiquidityForAmounts(newKey, swapParams.amount0Desired, swapParams.amount1Desired);

            (swapParams.newAmount0, swapParams.newAmount1) = PoolActions.getAmountsForLiquidity(newKey, newliquidity);

            zeroForOne = getZeroForOne(
                swapParams.amount0Desired, swapParams.amount1Desired, swapParams.newAmount0, swapParams.newAmount1
            );

            amountSpecified = zeroForOne
                ? int256(FullMath.mulDiv(swapParams.amount0Desired - swapParams.newAmount0, swapsPecentage, 100))
                : int256(FullMath.mulDiv(swapParams.amount1Desired - swapParams.newAmount1, swapsPecentage, 100));
        }
    }

    function getZeroForOne(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0,
        uint256 amount1
    )
        internal
        pure
        returns (bool zeroGreaterOne)
    {
        zeroGreaterOne =
            (amount0Desired - amount0) * amount1Desired > (amount1Desired - amount1) * amount0Desired ? true : false;
    }

    /// @notice Checks and updates the swap count within a single day threshold.
    /// @dev This function is used to limit the number of manual swaps within a 24-hour period.
    /// @param lastUpdateTimeStamp The last time the swap count was updated.
    /// @param manualSwapsCount The current count of manual swaps.
    /// @return uint256 The updated time stamp.
    /// @return uint256 The updated swap count.
    /// @custom:errors SwapsThresholdExceeded if the number of swaps exceeds the set threshold within a day.
    function _checkSwapsInADay(
        uint256 lastUpdateTimeStamp,
        uint256 manualSwapsCount
    )
        internal
        view
        returns (uint256, uint256)
    {
        if (block.timestamp <= lastUpdateTimeStamp + 1 days) {
            if (manualSwapsCount >= swapsThreshold) revert SwapsThresholdExceeded();
            return (lastUpdateTimeStamp, manualSwapsCount += 1);
        } else {
            return (block.timestamp, manualSwapsCount = 1);
        }
    }

    function getTicksForModeWithActions(
        ICLTBase.StrategyKey memory key,
        uint256 mode,
        bytes32 actionName
    )
        internal
        view
        returns (int24 tickLower, int24 tickUpper)
    {
        if (actionName == PRICE_PREFERENCE) {
            (tickLower, tickUpper) = getTicksForMode(key, mode);
        }
        if (actionName == ACTIVE_REBALANCE) {
            // The strategy is already verified in _checkActiveRebalancingStrategies()
            // so we dont need to check further we just need to create new ticks
            (tickLower, tickUpper) = getTicksForModeActive(key);
        }
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
        int24 currentTick = twapQuoter.getTwap(key.pool);

        if (mode == 1) {
            (tickLower, tickUpper) = shiftLeft(key, currentTick);
        } else if (mode == 2) {
            (tickLower, tickUpper) = shiftRight(key, currentTick);
        } else if (mode == 3) {
            (tickLower, tickUpper) = shiftBothSide(key, currentTick);
        }
    }

    /// @notice Computes ticks for active rebalancing in a given mode.
    /// @dev Logic to adjust the ticks based on mode.
    /// @param key Strategy key.
    /// @return tickLower and tickUpper values.
    function getTicksForModeActive(ICLTBase.StrategyKey memory key)
        internal
        view
        returns (int24 tickLower, int24 tickUpper)
    {
        int24 currentTick = twapQuoter.getTwap(key.pool);
        (tickLower, tickUpper) = shiftActive(key, currentTick);
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
        (ICLTBase.StrategyKey memory key,, bytes memory actionsData, bytes memory actionStatus,,,,,) =
            cltBase.strategies(strategyId);

        ICLTBase.PositionActions memory strategyActionsData = abi.decode(actionsData, (ICLTBase.PositionActions));

        uint256 actionDataLength = strategyActionsData.rebaseStrategy.length;
        for (uint256 i = 0; i < actionDataLength; i++) {
            if (
                strategyActionsData.rebaseStrategy[i].actionName == REBASE_INACTIVITY
                    && !_checkRebaseInactivityStrategies(strategyActionsData.rebaseStrategy[i], actionStatus)
            ) {
                return ExecutableStrategiesData(bytes32(0), uint256(0), [bytes32(0), bytes32(0), bytes32(0)]);
            }
        }

        ExecutableStrategiesData memory executableStrategiesData;
        uint256 count = 0;
        bool hasActiveRebalancing = false;
        bool hasPricePreference = false;
        for (uint256 i = 0; i < actionDataLength; i++) {
            ICLTBase.StrategyPayload memory rebaseAction = strategyActionsData.rebaseStrategy[i];

            if (shouldAddToQueue(rebaseAction, key, strategyActionsData.mode, hasActiveRebalancing, hasPricePreference))
            {
                // @audit-info need to test this logic thoroughly
                // below logic is to handle the case if rebaseActions array is passed from contract
                // directly then the first action among the two below in the array will be prioritized
                if (rebaseAction.actionName == ACTIVE_REBALANCE) {
                    hasActiveRebalancing = true;
                }
                if (rebaseAction.actionName == PRICE_PREFERENCE) {
                    hasPricePreference = true;
                }
                executableStrategiesData.actionNames[count++] = rebaseAction.actionName;
            }
        }

        if (count == 0) {
            return ExecutableStrategiesData(bytes32(0), uint256(0), [bytes32(0), bytes32(0), bytes32(0)]);
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
        uint256 mode,
        bool hasActiveRebalancing,
        bool hasPricePreference
    )
        internal
        view
        returns (bool)
    {
        if (rebaseAction.actionName == ACTIVE_REBALANCE) {
            return !hasPricePreference && _checkActiveRebalancingStrategies(key, rebaseAction.data, mode);
        } else if (rebaseAction.actionName == PRICE_PREFERENCE) {
            return !hasActiveRebalancing && _checkRebasePreferenceStrategies(key, rebaseAction.data, mode);
        }
        return true;
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
        (int24 lowerThresholDifference, int24 upperThresholDifference) = abi.decode(actionsData, (int24, int24));

        (int24 lowerThresholdTick, int24 upperThresholdTick) =
            _getPreferenceTicks(key, PRICE_PREFERENCE, lowerThresholDifference, upperThresholDifference);

        int24 tick = twapQuoter.getTwap(key.pool);

        if (mode == 2 && tick > key.tickUpper || mode == 1 && tick < key.tickLower || mode == 3) {
            if (tick < lowerThresholdTick || tick > upperThresholdTick) {
                return true;
            }
        }

        return false;
    }

    /// @notice Checks if strategies are satisfied for active rebalancing given key and action data.
    /// @param key The strategy key to be checked.
    /// @param actionsData The actions data that includes the rebase strategy data.
    /// @return true if the conditions are met, false otherwise.
    function _checkActiveRebalancingStrategies(
        ICLTBase.StrategyKey memory key,
        bytes memory actionsData,
        uint256 mode
    )
        internal
        view
        returns (bool)
    {
        (int24 lowerThresholDifference, int24 upperThresholDifference) = abi.decode(actionsData, (int24, int24));

        (int24 lowerThresholdTick, int24 upperThresholdTick) =
            _getPreferenceTicks(key, ACTIVE_REBALANCE, lowerThresholDifference, upperThresholDifference);

        int24 tick = twapQuoter.getTwap(key.pool);
        if (mode == 2 && tick > upperThresholdTick || mode == 1 && tick < lowerThresholdTick || mode == 3) {
            if (tick > upperThresholdTick || tick < lowerThresholdTick) {
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
            (uint256 rebaseCount,) = abi.decode(actionStatus, (uint256, bool));
            if (rebaseCount > 0 && preferredInActivity == rebaseCount) {
                return false;
            }
        }

        return true;
    }

    function _getPositionLiquidity(ICLTBase.StrategyKey memory key)
        internal
        view
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        bytes32 positionKey = PositionKey.compute(address(cltBase), key.tickLower, key.tickUpper);
        (liquidity, feeGrowthInside0LastX128, feeGrowthInside1LastX128, tokensOwed0, tokensOwed1) =
            key.pool.positions(positionKey);
    }

    /// @notice Validates the given strategy payload data for rebase strategies.
    /// @param actionsData The strategy payload to validate, containing action names and associated data.
    /// @return True if the strategy payload data is valid, otherwise it reverts.
    function checkInputData(ICLTBase.StrategyPayload memory actionsData) external pure override returns (bool) {
        bool hasDiffPreference = actionsData.actionName == PRICE_PREFERENCE;
        bool hasInActivity = actionsData.actionName == REBASE_INACTIVITY;
        bool hasActiveRebalancing = actionsData.actionName == ACTIVE_REBALANCE;

        if (hasDiffPreference && isNonZero(actionsData.data)) {
            (int24 lowerPreferenceDiff, int24 upperPreferenceDiff) = abi.decode(actionsData.data, (int24, int24));
            if (lowerPreferenceDiff <= 0 || upperPreferenceDiff <= 0) {
                revert InvalidRebalanceThresholdDifference();
            }
            return true;
        }

        if (hasInActivity) {
            uint256 preferredInActivity = abi.decode(actionsData.data, (uint256));

            if (preferredInActivity == 0) {
                revert RebaseInactivityCannotBeZero();
            }

            return true;
        }

        if (hasActiveRebalancing && isNonZero(actionsData.data)) {
            (int24 lowerPreferenceDiff, int24 upperPreferenceDiff) = abi.decode(actionsData.data, (int24, int24));
            if (lowerPreferenceDiff <= 0 || upperPreferenceDiff <= 0) {
                revert InvalidRebalanceThresholdDifference();
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
    function checkStrategiesArray(bytes32[] memory data) public returns (bool) {
        if (data.length == 0) {
            revert StrategyIdsCannotBeEmpty();
        }
        // check 0 strategyId
        uint256 dataLength = data.length;
        for (uint256 i = 0; i < dataLength; i++) {
            (, address strategyOwner,,,,,,,) = cltBase.strategies(data[i]);
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
    /// @param lowerThresholdDiff The lower preference difference.
    /// @param upperThresholdDiff The upper preference difference.
    /// @return lowerThresholdTick The calculated lower preference tick.
    /// @return upperThresholdTick The calculated upper preference tick.
    function _getPreferenceTicks(
        ICLTBase.StrategyKey memory _key,
        bytes32 actionName,
        int24 lowerThresholdDiff,
        int24 upperThresholdDiff
    )
        internal
        view
        returns (int24 lowerThresholdTick, int24 upperThresholdTick)
    {
        if (actionName == PRICE_PREFERENCE) {
            lowerThresholdTick = _key.tickLower - lowerThresholdDiff;
            upperThresholdTick = _key.tickUpper + upperThresholdDiff;
        } else {
            lowerThresholdTick = _key.tickLower + lowerThresholdDiff;
            upperThresholdTick = _key.tickUpper - upperThresholdDiff;
        }
    }

    function getPreferenceTicks(
        bytes32 strategyID,
        bytes32 actionName,
        bytes memory actionsData
    )
        external
        returns (int24 lowerPreferenceTick, int24 upperPreferenceTick)
    {
        (ICLTBase.StrategyKey memory key,,,,,,,,) = cltBase.strategies(strategyID);

        (int24 lowerPreferenceDiff, int24 upperPreferenceDiff) = abi.decode(actionsData, (int24, int24));

        (lowerPreferenceTick, upperPreferenceTick) =
            _getPreferenceTicks(key, actionName, lowerPreferenceDiff, upperPreferenceDiff);
    }

    /// @notice Updates the address twapQuoter.
    /// @param _twapQuoter The new address of twapQuoter
    function updateTwapQuoter(address _twapQuoter) external onlyOwner {
        twapQuoter = ICLTTwapQuoter(_twapQuoter);
    }

    /// @notice Updates the swaps threshold.
    /// @dev Reverts if the new threshold is less than zero.
    /// @param _newThreshold The new liquidity threshold value.
    function updateSwapsThreshold(uint256 _newThreshold) external onlyOperator {
        if (_newThreshold < 0) {
            revert InvalidThreshold();
        }
        swapsThreshold = _newThreshold;
    }

    /// @notice Updates the slippage percentage.
    /// @dev Reverts if the new slippage is greater than 50.
    /// @param _newSlippage The new liquidity threshold value.
    function updateSlippagePercentage(uint160 _newSlippage) external onlyOperator {
        if (_newSlippage >= 1e8) {
            revert SlippageThresholdExceeded();
        }
        slippage = _newSlippage;
    }
}
