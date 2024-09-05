// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { AccessControl } from "../../base/AccessControl.sol";

import { ICLTBase } from "../../interfaces/ICLTBase.sol";
import { ICLTTwapQuoter } from "../../interfaces/ICLTTwapQuoter.sol";
import { IExitStrategy } from "../../interfaces/modules/IExitStrategy.sol";

/// @title A51 Finance Autonomous Liquidity Provision Rebase Module Contract
/// @author undefined_0x
/// @notice This contract is part of the A51 Finance platform, focusing on automated liquidity provision and rebalancing
/// strategies. The RebaseModule contract is responsible for validating and verifying the strategies before executing
/// them through CLTBase.
contract ExitModule is AccessControl, IExitStrategy {
    /// @notice The address of base contract
    ICLTBase public immutable cltBase;

    /// @notice The address of twap quoter
    ICLTTwapQuoter public twapQuoter;

    // 0xc5777e329881bb35c6de0a859435b42924520885cd50bf0a8cef6a1552361851
    bytes32 public constant EXIT_PREFERENCE = keccak256("EXIT_PREFERENCE");

    constructor(address _governance, address _baseContractAddress, address _twapQuoter) AccessControl(_governance) {
        twapQuoter = ICLTTwapQuoter(_twapQuoter);
        cltBase = ICLTBase(payable(_baseContractAddress));
    }

    function executeExit(bytes32[] calldata strategyIDs) external {
        checkStrategiesArray(strategyIDs);
        ExecutableStrategiesData[] memory _queue = checkAndProcessStrategies(strategyIDs);
        uint256 queueLength = _queue.length;
        for (uint256 i = 0; i < queueLength; i++) {
            ICLTBase.ShiftLiquidityParams memory params;
            (ICLTBase.StrategyKey memory key,,, bytes memory actionStatus,,,,,) =
                cltBase.strategies(_queue[i].strategyID);

            params.strategyId = _queue[i].strategyID;
            params.key = key;
            params.shouldMint = false;
            params.swapAmount = 0;
            params.moduleStatus = actionStatus;

            cltBase.shiftLiquidity(params);
        }
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

    /// @notice Retrieves strategy data based on strategy ID.
    /// @param strategyId The Data of the strategy to retrieve.
    /// @return ExecutableStrategiesData representing the retrieved strategy.
    function getStrategyData(bytes32 strategyId) internal returns (ExecutableStrategiesData memory) {
        (ICLTBase.StrategyKey memory key,, bytes memory actionsData,,,,,,) = cltBase.strategies(strategyId);

        ICLTBase.PositionActions memory strategyActionsData = abi.decode(actionsData, (ICLTBase.PositionActions));
        uint256 actionDataLength = strategyActionsData.exitStrategy.length;
        ExecutableStrategiesData memory executableStrategiesData;
        uint256 count = 0;

        for (uint256 i = 0; i < actionDataLength; i++) {
            ICLTBase.StrategyPayload memory exitAction = strategyActionsData.exitStrategy[i];

            if (shouldAddToQueue(exitAction, key)) {
                executableStrategiesData.actionNames[count++] = exitAction.actionName;
            }
        }

        if (count == 0) {
            return ExecutableStrategiesData(bytes32(0), uint256(0), [bytes32(0)]);
        }

        executableStrategiesData.mode = strategyActionsData.mode;
        executableStrategiesData.strategyID = strategyId;
        return executableStrategiesData;
    }

    /// @notice Determines if a strategy should be added to the queue.
    /// @dev Checks the preference and other strategy details.
    /// @param exitAction  Data related to strategy actions.
    /// @param key Strategy key.
    /// @return bool indicating whether the strategy should be added to the queue.
    function shouldAddToQueue(
        ICLTBase.StrategyPayload memory exitAction,
        ICLTBase.StrategyKey memory key
    )
        internal
        view
        returns (bool)
    {
        if (exitAction.actionName == EXIT_PREFERENCE) {
            return _checkExitPreferenceStrategies(key, exitAction.data);
        }
        return false;
    }

    /// @notice Checks if rebase preference strategies are satisfied for the given key and action data.
    /// @param key The strategy key to be checked.
    /// @param actionsData The actions data that includes the rebase strategy data.
    /// @return true if the conditions are met, false otherwise.
    function _checkExitPreferenceStrategies(
        ICLTBase.StrategyKey memory key,
        bytes memory actionsData
    )
        internal
        view
        returns (bool)
    {
        (int24 lowerExitPreference, int24 upperExitPreference) = abi.decode(actionsData, (int24, int24));

        int24 tick = twapQuoter.getTwap(key.pool);

        if (tick < lowerExitPreference || tick > upperExitPreference) {
            return true;
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

    function checkInputData(ICLTBase.StrategyPayload memory actionsData) external pure returns (bool) {
        bool hasExitPreference = actionsData.actionName == EXIT_PREFERENCE;
        if (hasExitPreference && isNonZero(actionsData.data)) {
            (int24 lowerExitPreference, int24 upperExitPreference) = abi.decode(actionsData.data, (int24, int24));
            if (lowerExitPreference == upperExitPreference || lowerExitPreference > upperExitPreference) {
                revert InvalidExitPreference();
            }
            return true;
        }
        revert ExitStrategyDataCannotBeZero();
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
}
