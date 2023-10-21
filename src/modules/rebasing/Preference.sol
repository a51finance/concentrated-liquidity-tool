// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "../../CLTBase.sol";
import "../../interfaces/modules/IPreference.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

contract RebasePreference is Owned, IPreference {
    mapping(address operator => bool eligible) public operators;

    struct Data {
        bytes32 strategyId;
        uint64 actionId;
    }

    Data[] private _queue;
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

    function checkStrategies(bytes32[] memory strategyIDs, bool shouldExecute) external returns (Data[] memory) {
        for (uint256 i = 0; i < strategyIDs.length; i++) {
            (StrategyKey memory key, bytes memory actions, bytes memory actionsData,,,, uint256 totalShares,) =
                _cltBase.strategies(strategyIDs[i]);
            // add some more check here whether liquidity is in range
            if (totalShares > liquidityThreshold) {
                PositionActions memory positionActionData = abi.decode(actions, (PositionActions));
                processRebaseStrategies(key, actionsData, positionActionData, strategyIDs[i]);
            }
        }

        if (shouldExecute) {
            for (uint256 ids = 0; ids <= _queue.length; ids++) {
                // add checks here, incomplete now
                executeStrategies(_queue[ids]);
            }
        }

        return _queue;
    }

    function processRebaseStrategies(
        StrategyKey memory key,
        bytes memory actionsData,
        PositionActions memory positionActionData,
        bytes32 strategyID
    )
        internal
    {
        for (
            uint256 rebalanceModules = 0;
            rebalanceModules < positionActionData.rebasePreference.length;
            rebalanceModules++
        ) {
            uint256 preference = positionActionData.rebasePreference[rebalanceModules];

            if (preference == 1 && _checkRebasePreferenceStrategies(key, actionsData)) {
                _queue.push(Data(strategyID, 1));
            } else if (preference == 2 && _checkRebaseTimePreferenceStrategies()) {
                _queue.push(Data(strategyID, 2));
            } else if (preference == 3 && _checkRebaseInactivityStrategies()) {
                _queue.push(Data(strategyID, 3));
            }
        }
    }

    function executeStrategies(Data memory strategyData) internal view isOperator {
        // need to generalize this function as well
        (StrategyKey memory key, bytes memory actions, bytes memory actionsData,,,,,) =
            _cltBase.strategies(strategyData.strategyId);

        (int24 tickLower, int24 tickUpper) = _getTicks(key, actions);

        key.tickLower = tickLower;
        key.tickUpper = tickUpper;

        ShiftLiquidityParams memory params;
        params.key = key;
        params.strategyId = strategyData.strategyId;
        params.shouldMint = true;
        params.zeroForOne = false;
        params.swapAmount = 0;

        // _cltBase.shiftLiquidity(params);
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

    function _checkRebaseTimePreferenceStrategies() internal returns (bool) { }
    function _checkRebaseInactivityStrategies() internal returns (bool) { }

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

    function _getTicks(
        StrategyKey memory key,
        bytes memory positionActions
    )
        internal
        view
        returns (int24 tickLower, int24 tickUpper)
    {
        PositionActions memory positionActionsData = abi.decode(positionActions, (PositionActions));
        (tickLower, tickUpper) =
            _generatePositionTicks(key.pool, positionActionsData.mode, key.tickLower, key.tickUpper);
    }

    function _generatePositionTicks(
        IUniswapV3Pool _pool,
        uint8 _mode,
        int24 _tickLower,
        int24 _tickUpper
    )
        internal
        view
        returns (int24 tickLower, int24 tickUpper)
    {
        (, int24 _tick,,,,,) = _pool.slot0();

        _tick = _floor(_tick, _pool.tickSpacing());

        int24 tickDifference = _tickUpper - _tickLower;

        // dyanmic
        if (_mode == 1) {
            if (_tick > _tickUpper) {
                tickLower = _tick + (newTicksDifference * _pool.tickSpacing());
                tickUpper = tickUpper + tickDifference;
            }
            tickUpper = _tick - (newTicksDifference * _pool.tickSpacing());
            tickLower = tickUpper - tickDifference;
        }
        // left
        if (_mode == 2) {
            tickUpper = _tick - (newTicksDifference * _pool.tickSpacing());
            tickLower = tickUpper - tickDifference;
        }
        // right
        if (_mode == 3) {
            tickLower = _tick + (newTicksDifference * _pool.tickSpacing());
            tickUpper = tickUpper + tickDifference;
        }
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
