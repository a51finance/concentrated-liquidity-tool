// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "../../CLTBase.sol";
import "../../interfaces/modules/IPreference.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

contract RebasePreference is Owned, IPreference {
    mapping(address => bool) public operators;
    CLTBase cltBase;
    bytes32[] queue;

    modifier isOperator() {
        if (operators[msg.sender] == false) {
            revert InvalidCaller();
        }
        _;
    }

    constructor(address _cltBase, address _owner) Owned(_owner) {
        cltBase = CLTBase(payable(_cltBase));
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
    function executeStrategies(bytes32 strategyID) internal view isOperator {
        (StrategyKey memory key, bytes memory actions, bytes memory actionsData,,,,,) = cltBase.strategies(strategyID);

        /**
         * take the percentage of current tick
         * check ticks are floored
         * update the states
         */

        getNewPreference(key.pool, actionsData);

        ShiftLiquidityParams memory params;
        params.key = key;
        params.strategyId = strategyID;
        params.shouldMint = false;
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
        (tick,) = OracleLibrary.consult(_pool, 300);
    }
}
