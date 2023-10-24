// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "../../CLTBase.sol";
import "../../interfaces/modules/IPreference.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

contract RebasePreference is Owned, IPreference {
    mapping(address operator => bool eligible) public operators;

    // Data[] private _queue;
    CLTBase private _cltBase;

    uint32 public twapDuration;
    uint256 liquidityThreshold = 1e3;
    // add a setter function for this
    int24 newTicksDifference = 3;

    modifier isOperator() {
        if (operators[msg.sender] == false) {
            revert InvalidCaller();
        }
        _;
    }

    constructor(address __cltBase, address _owner) Owned(_owner) {
        _cltBase = CLTBase(payable(__cltBase));
        twapDuration = 300;
    }

    function executeStrategies(bytes32[] memory strategyIDs) external view isOperator {
        StrategyData[] memory _queue = checkAndProcessStrategies(strategyIDs);
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
        (StrategyKey memory key, bytes memory actions,,,,, uint256 totalShares,) = _cltBase.strategies(strategyID);

        if (totalShares <= liquidityThreshold) {
            return StrategyData(bytes32(0), [uint64(0), uint64(0), uint64(0)]);
        }

        PositionActions memory positionActionData = abi.decode(actions, (PositionActions));
        if (positionActionData.rebasePreference.length > 3) {
            revert InvalidModesLength();
        }

        StrategyData memory data;
        uint256 count = 0;
        for (uint256 i = 0; i < positionActionData.rebasePreference.length; i++) {
            uint64 preference = positionActionData.rebasePreference[i];
            if (shouldAddToQueue(preference, key, actions)) {
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
        bytes memory actions
    )
        internal
        view
        returns (bool)
    {
        if (preference == 1) {
            return _checkRebasePreferenceStrategies(key, actions);
        } else if (preference == 2) {
            return _checkRebaseTimePreferenceStrategies();
        } else if (preference == 3) {
            return _checkRebaseInactivityStrategies();
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
        ActionsData memory data = abi.decode(actionsData, (ActionsData));

        (int24 lowerPreferenceDiff, int24 upperPreferenceDiff) =
            abi.decode(data.rebasePreferenceData[0], (int24, int24));

        (int24 lowerPreferenceTick, int24 upperPreferenceTick) =
            _getPreferenceTicks(key, lowerPreferenceDiff, upperPreferenceDiff);

        int24 tick = getTwap(address(key.pool));

        if (tick < lowerPreferenceTick || tick > upperPreferenceTick) {
            return true;
        }
        return false;
    }

    function _checkRebaseTimePreferenceStrategies() internal view returns (bool) { }
    function _checkRebaseInactivityStrategies() internal view returns (bool) { }

    function checkInputData(bytes32[] memory data) public returns (bool) {
        if (data.length == 0) {
            revert StrategyIdsCannotBeEmpty();
        }

        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == bytes32(0)) {
                revert StrategyIdCannotBeZero();
            }

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

    function getTwap(address _pool) public view returns (int24 tick) {
        (tick,) = OracleLibrary.consult(_pool, twapDuration);
    }

    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function updateTwapDuration(uint24 _durationInSeconds) external {
        twapDuration = _durationInSeconds;
    }

    function updateLiquidityThreshold(uint256 _newThreshold) external {
        if (_newThreshold <= 0) {
            revert InvalidThreshold();
        }
        liquidityThreshold = _newThreshold;
    }
}
