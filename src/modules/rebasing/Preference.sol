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

            if (totalShares > liquidityThreshold) {
                PositionActions memory positionActionData = abi.decode(actions, (PositionActions));
                processRebaseStrategies(key, actionsData, positionActionData, strategyIDs[i]);
            }
        }

        if (shouldExecute) {
            for (uint256 ids = 0; ids <= _queue.length; ids++) {
                // add checks here, incomplete now
                // check here if any of the transaction failed here or not
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

        (int24 tickLower, int24 tickUpper) = _getTicks(key.pool, actionsData);

        key.tickLower = tickLower;
        key.tickUpper = tickUpper;

        ShiftLiquidityParams memory params;
        params.key = key;
        params.strategyId = strategyID;
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
    }

    function toggleOperator(address operatorAddress) external onlyOwner {
        operators[operatorAddress] = !operators[operatorAddress];
    }

    function getTwap(address _pool) public view returns (int24 tick) {
        (tick,) = OracleLibrary.consult(_pool, twapDuration);
    }

    function _getTicks(
        IUniswapV3Pool _pool,
        bytes memory actionsData
    )
        internal
        view
        returns (int24 tickLower, int24 tickUpper)
    {
        ActionsData memory data = abi.decode(actionsData, (ActionsData));

        (,, int24 lowerTickDiff, int24 upperTickDiff) =
            abi.decode(data.rebasePreferenceData[0], (int24, int24, int24, int24));

        (, int24 tick,,,,,) = _pool.slot0();

        tickLower = _floor(tick - lowerTickDiff, _pool.tickSpacing());
        tickUpper = _floor(tick + upperTickDiff, _pool.tickSpacing());
    }

    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function updateTwapDuration(uint24 _durationInSeconds) external {
        twapDuration = _durationInSeconds;
    }
}
