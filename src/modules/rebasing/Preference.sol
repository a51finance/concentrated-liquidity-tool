// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "../../CLTBase.sol";
import "../../interfaces/modules/IPreference.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

contract RebasePreference is Owned, IPreference {
    mapping(address operator => bool eligible) public operators;
    CLTBase private cltBase;
    bytes32[] private queue;
    uint32 public twapDuration;

    modifier isOperator() {
        if (operators[msg.sender] == false) {
            revert InvalidCaller();
        }
        _;
    }

    constructor(address _cltBase, address _owner) Owned(_owner) {
        cltBase = CLTBase(payable(_cltBase));
        twapDuration = 300;
    }

    function checkStrategies(bytes32[] memory strategyIDs) external returns (bytes32[] memory) {
        for (uint256 i = 0; i < strategyIDs.length; i++) {
            (StrategyKey memory key, bytes memory actions, bytes memory actionsData,,,,,) =
                cltBase.strategies(strategyIDs[i]);
            PositionActions memory positionActionData = abi.decode(actions, (PositionActions));
            if (positionActionData.rebasePreference.length > 0) {
                ActionsData memory data = abi.decode(actionsData, (ActionsData));
                RebasePereferenceParams memory rebaseActionData =
                    abi.decode(data.rebasePreferenceData[0], (RebasePereferenceParams));
                int24 tick = getTwap(address(key.pool));
                if (tick > rebaseActionData.upperPreference || tick < rebaseActionData.lowerPreference) {
                    queue.push(strategyIDs[i]);
                }
            }
        }
        return queue;
    }

    // The function will be called by the bot in loop
    function executeStrategies(bytes32 strategyID) internal isOperator {
        (StrategyKey memory key,, bytes memory actionsData,,,,,) = cltBase.strategies(strategyID);

        getNewPreference(key.pool, actionsData);
        (int24 tickLower, int24 tickUpper) = getTicks(key.pool, actionsData);

        key.tickLower = tickLower;
        key.tickUpper = tickUpper;

        ShiftLiquidityParams memory params;
        params.key = key;
        params.strategyId = strategyID;
        params.shouldMint = true;
        params.zeroForOne = false;
        params.swapAmount = 0;

        cltBase.shiftLiquidity(params);
    }

    function toggleOperator(address operatorAddress) external onlyOwner {
        operators[operatorAddress] = !operators[operatorAddress];
    }

    function getNewPreference(IUniswapV3Pool pool, bytes memory actionsData) internal view {
        ActionsData memory data = abi.decode(actionsData, (ActionsData));
        RebasePereferenceParams memory rebaseActionData =
            abi.decode(data.rebasePreferenceData[0], (RebasePereferenceParams));
        (, int24 tick,,,,,) = pool.slot0();

        // need to check this logic
        int24 tickSpacing = pool.tickSpacing();

        int24 newLowerPreference =
            (((tick * rebaseActionData.lowerPercentage) / 100) / int24(tickSpacing)) * int24(tickSpacing);
        int24 newUpperPreference =
            (((tick * rebaseActionData.lowerPercentage) / 100) / int24(tickSpacing)) * int24(tickSpacing);

        require(newLowerPreference % tickSpacing == 0, "TLI");
        require(newUpperPreference % tickSpacing == 0, "TUI");

        rebaseActionData.lowerPreference = newLowerPreference;
        rebaseActionData.upperPreference = newUpperPreference;
    }

    function getTwap(address _pool) public view returns (int24 tick) {
        (tick,) = OracleLibrary.consult(_pool, twapDuration);
    }

    function getTicks(
        IUniswapV3Pool _pool,
        bytes memory actionsData
    )
        internal
        view
        returns (int24 tickLower, int24 tickUpper)
    {
        ActionsData memory data = abi.decode(actionsData, (ActionsData));
        RebasePereferenceParams memory rebaseActionData =
            abi.decode(data.rebasePreferenceData[0], (RebasePereferenceParams));
        (, int24 tick,,,,,) = _pool.slot0();
        int24 tickFloor = floor(tick, _pool.tickSpacing());
        tickLower = tickFloor - rebaseActionData.lowerBaseThreshold;
        tickUpper = tickFloor + rebaseActionData.upperBaseThreshold;
    }

    function floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function updateTwapDuration(uint24 _durationInSeconds) external {
        twapDuration = _durationInSeconds;
    }
}
