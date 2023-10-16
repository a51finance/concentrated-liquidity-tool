// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "../../CLTBase.sol";
import "../../interfaces/modules/IPreference.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "forge-std/console.sol";

contract RebasePreference is Owned, IPreference {
    mapping(address operator => bool eligible) public operators;

    bytes32[] private _queue;
    CLTBase private _cltBase;

    uint32 public twapDuration;

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

    function checkStrategies(bytes32[] memory strategyIDs) external returns (bytes32[] memory) {
        for (uint256 i = 0; i < strategyIDs.length; i++) {
            (StrategyKey memory key, bytes memory actions, bytes memory actionsData,,,,,) =
                _cltBase.strategies(strategyIDs[i]);

            PositionActions memory positionActionData = abi.decode(actions, (PositionActions));

            if (positionActionData.rebasePreference.length > 0) {
                ActionsData memory data = abi.decode(actionsData, (ActionsData));

                //     int24 lowerPreferenceDiff;
                //     int24 upperPreferenceDiff;
                //     int24 lowerTickDiff;
                //     int24 upperTickDiff;

                (int24 lowerPreferenceDiff, int24 upperPreferenceDiff,,) =
                    abi.decode(data.rebasePreferenceData[0], (int24, int24, int24, int24));

                int24 tick = getTwap(address(key.pool));

                (int24 lowerPreferenceTick, int24 upperPreferenceTick) =
                    _getPreferenceTicks(lowerPreferenceDiff, upperPreferenceDiff, key);

                if (tick < lowerPreferenceTick || tick > upperPreferenceTick) {
                    _queue.push(strategyIDs[i]);
                }
            }
        }
        return _queue;
    }

    // The function will be called by the bot in loop
    function executeStrategies(bytes32 strategyID) external view isOperator {
        (StrategyKey memory key,, bytes memory actionsData,,,,,) = _cltBase.strategies(strategyID);

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

    function _getPreferenceTicks(
        int24 lowerPreferenceDiff,
        int24 upperPreferenceDiff,
        StrategyKey memory key
    )
        internal
        pure
        returns (int24 lowerPreferenceTick, int24 upperPreferenceTick)
    {
        upperPreferenceTick = key.tickUpper + upperPreferenceDiff;
        lowerPreferenceTick = key.tickLower + lowerPreferenceDiff;
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
