// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "../../CLTBase.sol";
import "../../base/ModeTicksCalculation.sol";
import "../../interfaces/modules/IPreference.sol";

contract RebaseModule is Owned, ModeTicksCalculation, IPreference {
    mapping(address operator => bool eligible) public operators;

    CLTBase private _cltBase;

    uint32 public twapDuration;
    uint256 public liquidityThreshold = 1e3;
    uint256 public maxTimePeriod;

    modifier isOperator() {
        if (operators[msg.sender] == false) {
            revert InvalidCaller();
        }
        _;
    }

    constructor(address __cltBase, address _owner) Owned(_owner) {
        _cltBase = CLTBase(payable(__cltBase));
        maxTimePeriod = 31_536_000;
    }

    function executeStrategies(bytes32[] memory strategyIDs) external view isOperator {
        checkInputData(strategyIDs);

        StrategyData[] memory _queue = checkAndProcessStrategies(strategyIDs);

        for (uint256 i = 0; i < _queue.length; i++) {
            ShiftLiquidityParams memory params;
            StrategyKey memory key;
            params.strategyId = _queue[i];
            params.shouldMint = false;
            params.swapAmount = false;

            for (uint256 j = 0; j < _queue[i].modes.length; j++) {
                (int24 tickLower, int24 tickUpper) = getTicksForMode(_queue[i].modes[j]);

                key.tickLower = tickLower;
                key.tickUpper = tickUpper;
                params.key = key;
                _cltBase.shiftLiquidity(params);
                // need to update rebase number for specific strategy
            }
        }

        emit Executed(_queue);
    }

    function getTicksForMode(uint256 mode) internal view returns (int24 tickLower, int24 tickUpper) {
        if (mode == 1) {
            (tickLower, tickUpper) = shiftLeft(key, positionWidth);
        } else if (mode == 2) {
            (tickLower, tickUpper) = shiftRight(key, positionWidth);
        } else if (mode == 3) {
            // (tickLower, tickUpper) = shiftBothSide(key, positionWidth);
        }
        revert InvalidMode();
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
        (
            StrategyKey memory key,
            bytes memory actions,
            ,
            ,
            bool isRebaseActive,
            uint256 inActivityThreshold,
            ,
            ,
            uint256 totalShares,
            ,
            ,
        ) = _cltBase.strategies(strategyID);

        if (totalShares <= liquidityThreshold) {
            return StrategyData(bytes32(0), [uint64(0), uint64(0), uint64(0)]);
        }

        PositionActions memory positionActionData = abi.decode(actions, (PositionActions));
        ActionsData memory actionsData = abi.decode(actions, (ActionsData));

        //  we should check here the rebase threshold
        if (isRebaseActive && inActivityThreshold > 0 && _checkRebaseInactivityStrategies(actionsData)) {
            return StrategyData(bytes32(0), [uint64(0), uint64(0), uint64(0)]);
        }

        if (positionActionData.rebaseStrategy.length > 2) {
            revert InvalidModesLength();
        }

        StrategyData memory data;
        uint256 count = 0;
        for (uint256 i = 0; i < positionActionData.rebaseStrategy.length; i++) {
            uint64 preference = positionActionData.rebaseStrategy[i];
            if (shouldAddToQueue(preference, key, actionsData)) {
                data.modes[count++] = preference;
            }
        }

        if (count == 0) {
            return StrategyData(bytes32(0), [uint64(0), uint64(0), uint64(0)]);
        }

        data.strategyID = strategyID;
        return data;
    }

    function shouldAddToQueue(
        uint64 preference,
        StrategyKey memory key,
        bytes memory actionsData
    )
        internal
        view
        returns (bool)
    {
        if (preference == 1) {
            return _checkRebasePreferenceStrategies(key, actionsactionsData);
        } else if (preference == 2) {
            return _checkRebaseTimePreferenceStrategies(actionsData);
        } else if (preference == 3) {
            return _checkRebaseInactivityStrategies(actionsData);
        }
        return false;
    }

    function _checkRebasePreferenceStrategies(
        StrategyKey memory key,
        bytes memory actionsData
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

        int24 tick = getTwap(address(key.pool));

        if (tick < lowerPreferenceTick || tick > upperPreferenceTick) {
            return true;
        }
        return false;
    }

    function _checkRebaseTimePreferenceStrategies(bytes memory actionsData) internal view returns (bool) {
        // rebase preference data will be encode with uint256
        (uint256 timePreference) = abi.decode(actionsData.rebaseStrategyData[1], (uint256));
        // How can we use these checks at the time of strategy creation?
        if (timePreference < block.timestamp || timePreference >= maxTimePeriod || timePreference == 0) {
            revert timePreferenceConstraint();
        }
        return true;
    }

    // Return true if they match
    function _checkRebaseInactivityStrategies(bytes memory actionsData) internal view returns (bool) {
        (,,,, bool isRebaseActive, uint256 inActivityThreshold,,,,,,) = _cltBase.strategies(strategyID);

        if (!isRebaseActive) {
            StrategyData storage strategiesData = _cltBase.strategies(strategyID);
            strategiesData.isRebaseActive = true;
        }

        (uint256 preferredInActivity) = abi.decode(actionsData.rebaseStrategyData[2], (uint256));

        if (inActivityThreshold == preferredInActivity) {
            return true;
        }

        return false;
    }

    function checkInputData(bytes32[] memory data, uint64 mode) public returns (bool) {
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

    function toggleOperator(address operatorAddress) external onlyOwner {
        operators[operatorAddress] = !operators[operatorAddress];
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
