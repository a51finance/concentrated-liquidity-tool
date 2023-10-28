// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

// Importing foundational and interfaced contracts
import "../../base/ModeTicksCalculation.sol";
import "../../base/AccessControl.sol";
import "../../interfaces/modules/IPreference.sol";
import "../../interfaces/ICLTBase.sol";

/// @title Rebase Module Contract
contract RebaseModule is ModeTicksCalculation, AccessControl, ICLTBase, IPreference {
    /// @notice Threshold for liquidity consideration
    uint256 public liquidityThreshold = 1e3;
    /// @notice Maximum allowable time period
    uint256 public maxTimePeriod;

    ICLTBase _cltBase; // Instance of the ICLTBase interface

    /// @notice Constructs the RebaseModule with the provided parameters.
    /// @param __cltBase Address of the CLTBase.
    /// @param _owner Address of the owner.
    /// @param _baseContract Address of the base contract.
    constructor(address __cltBase, address _owner, address _baseContract) AccessControl(_owner) {
        _cltBase = ICLTBase(payable(_baseContract));
        maxTimePeriod = 31_536_000; // Represents seconds in a year.
    }

    /// @notice Executes given strategies.
    /// @dev Can only be called by the operator.
    /// @param strategyIDs Array of strategy IDs to be executed.
    function executeStrategies(bytes32[] memory strategyIDs) external onlyOperator {
        checkStrategiesArray(strategyIDs);

        StrategyData[] memory _queue = checkAndProcessStrategies(strategyIDs);

        for (uint256 i = 0; i < _queue.length; i++) {
            ShiftLiquidityParams memory params;
            (StrategyKey memory key,,, bytes memory actionStatus,,,,,,,) = _cltBase.strategies(_queue[i].strategyID);
            uint256 rebaseCount = abi.decode(actionStatus, (uint256));
            params.strategyId = _queue[i].strategyID;
            params.shouldMint = false;
            params.swapAmount = 0;

            for (uint256 j = 0; j < _queue[i].modes.length; j++) {
                (int24 tickLower, int24 tickUpper) = getTicksForMode(key, _queue[i].modes[j]);
                if (tickLower == 0 && tickUpper == 0) revert BothTicksCannotBeZero();
                key.tickLower = tickLower;
                key.tickUpper = tickUpper;
                params.key = key;
                params.moduleStatus = _queue[i].modes[j] == 3 ? abi.encode(uint256(++rebaseCount)) : actionStatus;
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
        return (tickLower = 0, tickUpper = 0);
    }

    /// @notice Checks and processes strategies based on their validity.
    /// @dev Returns an array of valid strategies.
    /// @param strategyIDs Array of strategy IDs to check and process.
    /// @return StrategyData[] array containing valid strategies.
    function checkAndProcessStrategies(bytes32[] memory strategyIDs) internal view returns (StrategyData[] memory) {
        StrategyData[] memory _queue = new StrategyData[](strategyIDs.length);
        uint256 validEntries = 0;

        for (uint256 i = 0; i < strategyIDs.length; i++) {
            StrategyData memory data = getStrategyData(strategyIDs[i]);
            if (data.strategyID != bytes32(0)) {
                _queue[validEntries++] = data;
            }
        }
        return _queue;
    }

    /// @notice Retrieves strategy data based on strategy ID.
    /// @param strategyID The ID of the strategy to retrieve.
    /// @return StrategyData representing the retrieved strategy.
    function getStrategyData(bytes32 strategyID) internal view returns (StrategyData memory) {
        (StrategyKey memory key, bytes memory actions,, bytes memory actionStatus,,,, uint256 totalShares,,,) =
            _cltBase.strategies(strategyID);

        if (totalShares <= liquidityThreshold) {
            return StrategyData(bytes32(0), [uint256(0), uint256(0), uint256(0)]);
        }

        PositionActions memory positionActionData = abi.decode(actions, (PositionActions));
        ActionsData memory actionsData = abi.decode(actions, (ActionsData));

        if (positionActionData.rebaseStrategy.length > 2) {
            revert InvalidModesLength();
        }

        StrategyData memory data;
        uint256 count = 0;
        for (uint256 i = 0; i < positionActionData.rebaseStrategy.length; i++) {
            uint256 preference = positionActionData.rebaseStrategy[i];

            if (_checkRebaseInactivityStrategies(actionsData, actionStatus)) {
                if (shouldAddToQueue(preference, key, actionsData)) {
                    data.modes[count++] = preference;
                }
            }
        }

        if (count == 0) {
            return StrategyData(bytes32(0), [uint256(0), uint256(0), uint256(0)]);
        }

        data.strategyID = strategyID;
        return data;
    }

    /// @notice Determines if a strategy should be added to the queue.
    /// @dev Checks the preference and other strategy details.
    /// @param preference The preference of the strategy.
    /// @param key Strategy key.
    /// @param actionsData Data related to strategy actions.
    /// @return bool indicating whether the strategy should be added to the queue.
    function shouldAddToQueue(
        uint256 preference,
        StrategyKey memory key,
        ActionsData memory actionsData
    )
        internal
        view
        returns (bool)
    {
        if (preference == 1) {
            return _checkRebasePreferenceStrategies(key, actionsData);
        } else if (preference == 2) {
            return _checkRebaseTimePreferenceStrategies(actionsData);
        }
        return false;
    }

    /// @notice Checks if rebase preference strategies are satisfied for the given key and action data.
    /// @param key The strategy key to be checked.
    /// @param actionsData The actions data that includes the rebase strategy data.
    /// @return true if the conditions are met, false otherwise.
    function _checkRebasePreferenceStrategies(
        StrategyKey memory key,
        ActionsData memory actionsData
    )
        internal
        view
        returns (bool)
    {
        // rebase preference data will be encode with int24 and int24 types

        (int24 lowerPreferenceDiff, int24 upperPreferenceDiff) =
            abi.decode(actionsData.rebaseStrategyData[0], (int24, int24));

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
    function _checkRebaseTimePreferenceStrategies(ActionsData memory actionsData) internal view returns (bool) {
        uint256 timePreference = abi.decode(actionsData.rebaseStrategyData[1], (uint256));
        if (timePreference < block.timestamp || timePreference >= maxTimePeriod || timePreference == 0) {
            revert TimePreferenceConstraint();
        }
        return true;
    }

    /// @notice Checks if the rebase inactivity strategies are satisfied.
    /// @param actionsData The actions data that includes the rebase strategy data.
    /// @param actionStatus The status of the action.
    /// @return true if the conditions are met, false otherwise.
    function _checkRebaseInactivityStrategies(
        ActionsData memory actionsData,
        bytes memory actionStatus
    )
        internal
        pure
        returns (bool)
    {
        uint256 preferredInActivity = abi.decode(actionsData.rebaseStrategyData[2], (uint256));
        uint256 rebaseCount = abi.decode(actionStatus, (uint256));
        if (rebaseCount > 0 && preferredInActivity == rebaseCount) {
            return false;
        }

        return true;
    }

    /// @notice Checks the input data for validity.
    /// @param data An array of encoded actions data.
    /// @return true if the input data is valid.
    function checkInputData(bytes[] memory data) external returns (bool) {
        for (uint256 i = 0; i < data.length; i++) {
            ActionsData memory actionsData = abi.decode(data[i], (ActionsData));

            if (actionsData.rebaseStrategyData.length == 0) {
                revert RebaseStrategyDataCannotBeZero();
            }
            if (isNonZero(actionsData.rebaseStrategyData[0])) {
                (int24 lowerPreferenceDiff, int24 upperPreferenceDiff) =
                    abi.decode(actionsData.rebaseStrategyData[0], (int24, int24));

                if (lowerPreferenceDiff <= 0 || upperPreferenceDiff <= 0) {
                    revert InvalidPreferenceDifference();
                }
            }
            if (isNonZero(actionsData.rebaseStrategyData[1])) { }
            if (isNonZero(actionsData.rebaseStrategyData[2])) { }
        }
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
    function checkStrategiesArray(bytes32[] memory data) public returns (bool) {
        // check array length
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

    /// @notice Calculates the preference ticks based on the strategy key and the given preference differences.
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
    function updateLiquidityThreshold(uint256 _newThreshold) external {
        if (_newThreshold <= 0) {
            revert InvalidThreshold();
        }
        liquidityThreshold = _newThreshold;
    }

    /// @notice Fetches details of a particular strategy
    /// @param strategyId The unique identifier for the strategy
    /// @return key The key data of the strategy
    /// @return actions The actions associated with the strategy
    /// @return actionsData Additional data for the actions
    /// @return actionStatus The status of each action
    /// @return isCompound Boolean indicating if the strategy uses compounding
    /// @return balance0 The balance of token 0
    /// @return balance1 The balance of token 1
    /// @return totalShares The total shares associated with this strategy
    /// @return uniswapLiquidity The liquidity provided in Uniswap
    /// @return feeGrowthInside0LastX128 The fee growth for token 0
    /// @return feeGrowthInside1LastX128 The fee growth for token 1
    function strategies(bytes32 strategyId)
        external
        override
        returns (
            StrategyKey memory key,
            bytes memory actions,
            bytes memory actionsData,
            bytes memory actionStatus,
            bool isCompound,
            uint256 balance0,
            uint256 balance1,
            uint256 totalShares,
            uint128 uniswapLiquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128
        )
    { }

    /// @notice Fetches position details using the position identifier
    /// @param positionId The unique identifier for the position
    /// @return strategyId The strategy ID associated with this position
    /// @return liquidityShare The liquidity share for this position
    /// @return feeGrowthInside0LastX128 The fee growth for token 0
    /// @return feeGrowthInside1LastX128 The fee growth for token 1
    /// @return tokensOwed0 The tokens owed for token 0
    /// @return tokensOwed1 The tokens owed for token 1
    function positions(uint256 positionId)
        external
        override
        returns (
            bytes32 strategyId,
            uint256 liquidityShare,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    { }

    /// @notice Allows a user to deposit and create a new position
    /// @param params The deposit parameters
    /// @return tokenId The unique identifier for the position created
    /// @return liquidity The liquidity amount
    /// @return amount0 The amount of token 0 deposited
    /// @return amount1 The amount of token 1 deposited
    function deposit(DepositParams calldata params)
        external
        payable
        override
        returns (uint256 tokenId, uint256 liquidity, uint256 amount0, uint256 amount1)
    { }

    /// @notice Allows a user to withdraw from their position
    /// @param params The withdrawal parameters
    /// @return amount0 The amount of token 0 withdrawn
    /// @return amount1 The amount of token 1 withdrawn
    function withdraw(WithdrawParams calldata params) external override returns (uint256 amount0, uint256 amount1) { }

    /// @notice Allows a user to claim fees from their position
    /// @param params The parameters required to claim fees
    function claimPositionFee(ClaimFeesParams calldata params) external override { }

    /// @notice Allows a user to shift their liquidity
    /// @param params The parameters required to shift liquidity
    function shiftLiquidity(ShiftLiquidityParams calldata params) external override { }
}
