// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "../../CLTBase.sol";
import "../../base/ModeTicksCalculation.sol";
import "../../base/AccessControl.sol";
import "../../interfaces/modules/IPreference.sol";

abstract contract RebaseModule is Owned, ModeTicksCalculation, AccessControl, IPreference {
    CLTBase private _cltBase;

    uint256 public liquidityThreshold = 1e3;
    uint256 public maxTimePeriod;

    constructor(address __cltBase) {
        _cltBase = CLTBase(payable(__cltBase));
        maxTimePeriod = 31_536_000;
    }

    function executeStrategies(bytes32[] memory strategyIDs) external onlyOperator {
        checkInputData(strategyIDs);

        StrategyData[] memory _queue = checkAndProcessStrategies(strategyIDs);

        for (uint256 i = 0; i < _queue.length; i++) {
            ShiftLiquidityParams memory params;
            (StrategyKey memory key,,,,,,,,,,) = _cltBase.strategies(_queue[i].strategyID);

            params.strategyId = _queue[i].strategyID;
            params.shouldMint = false;
            params.swapAmount = 0;

            for (uint256 j = 0; j < _queue[i].modes.length; j++) {
                (int24 tickLower, int24 tickUpper) = getTicksForMode(key, _queue[i].modes[j]);
                if (tickLower == 0 && tickUpper == 0) revert BothTicksCannotBeZero();
                key.tickLower = tickLower;
                key.tickUpper = tickUpper;
                params.key = key;

                _cltBase.shiftLiquidity(params);
                // need to update rebase number for specific strategy
            }
        }

        // emit Executed(_queue);
    }

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
            // (tickLower, tickUpper) = shiftBothSide(key, positionWidth);
        }
        return (tickLower = 0, tickUpper = 0);
    }

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

    function getStrategyData(bytes32 strategyID) internal view returns (StrategyData memory) {
        (StrategyKey memory key, bytes memory actions,,,, uint256 rebaseCount,, uint256 totalShares,,,) =
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

            if (_checkRebaseInactivityStrategies(actionsData, rebaseCount)) {
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

    function _checkRebaseTimePreferenceStrategies(ActionsData memory actionsData) internal view returns (bool) {
        // rebase preference data will be encode with uint256
        (uint256 timePreference) = abi.decode(actionsData.rebaseStrategyData[1], (uint256));
        // How can we use these checks at the time of strategy creation?
        if (timePreference < block.timestamp || timePreference >= maxTimePeriod || timePreference == 0) {
            revert TimePreferenceConstraint();
        }
        return true;
    }

    // Return true if they match
    function _checkRebaseInactivityStrategies(
        ActionsData memory actionsData,
        uint256 rebaseCount
    )
        internal
        pure
        returns (bool)
    {
        (uint256 preferredInActivity) = abi.decode(actionsData.rebaseStrategyData[2], (uint256));

        if (rebaseCount > 0 && preferredInActivity == rebaseCount) {
            return false;
        }

        return true;
    }

    function checkInputData(bytes32[] memory data) public pure returns (bool) {
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

    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function updateLiquidityThreshold(uint256 _newThreshold) external {
        if (_newThreshold <= 0) {
            revert InvalidThreshold();
        }
        liquidityThreshold = _newThreshold;
    }
}
