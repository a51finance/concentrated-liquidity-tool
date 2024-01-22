// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase } from "../../interfaces/ICLTBase.sol";
import { AccessControl } from "../../base/AccessControl.sol";
import { ModeTicksCalculation } from "../../base/ModeTicksCalculation.sol";

/// @title  Modes
/// @notice Provides functions to update ticks for basic modes of strategy
contract Modes is ModeTicksCalculation, AccessControl {
    error InvalidModeId(uint256 modeId);
    error InvalidStrategyId(bytes32 strategyID);

    /// @notice The address of base vault
    ICLTBase public baseVault;

    constructor(address vault, address owner) AccessControl(owner) {
        baseVault = ICLTBase(vault);
    }

    /// @notice Trails the position of strategy according to the current tick i.e. shift left or shift right
    /// @param strategyIDs List of hashes of individual strategy ID
    function ShiftBase(bytes32[] calldata strategyIDs) external {
        uint256 strategyIdsLength = strategyIDs.length;

        for (uint256 i = 0; i < strategyIdsLength; i++) {
            (ICLTBase.StrategyKey memory key, bytes memory actions) = _getStrategy(strategyIDs[i]);

            if (address(key.pool) == address(0)) revert InvalidStrategyId(strategyIDs[i]);
            ICLTBase.PositionActions memory modules = abi.decode(actions, (ICLTBase.PositionActions));

            if (modules.mode == 1) {
                _shiftLeftBase(strategyIDs[i], key);
            } else if (modules.mode == 2) {
                _shiftRightBase(strategyIDs[i], key);
            } else if (modules.mode == 3) {
                _shiftLeftAndRightBase(strategyIDs[i], key);
            } else {
                revert InvalidModeId(modules.mode);
            }
        }
    }

    /// @notice Trails the position of strategy to the left close to current tick
    /// @param strategyID Hash of strategy ID
    /// @param key A51 strategy key details
    /// @return tickLower The lower tick of the range
    /// @return tickUpper The upper tick of the range
    function _shiftLeftBase(
        bytes32 strategyID,
        ICLTBase.StrategyKey memory key
    )
        internal
        returns (int24 tickLower, int24 tickUpper)
    {
        (tickLower, tickUpper) = shiftLeft(key);
        key = ICLTBase.StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });
        _updateStrategy(strategyID, key);
    }

    /// @notice Trails the position of strategy to the right close to current tick
    /// @param strategyID Hash of strategy ID
    /// @param key A51 strategy key details
    /// @return tickLower The lower tick of the range
    /// @return tickUpper The upper tick of the range
    function _shiftRightBase(
        bytes32 strategyID,
        ICLTBase.StrategyKey memory key
    )
        internal
        returns (int24 tickLower, int24 tickUpper)
    {
        (tickLower, tickUpper) = shiftRight(key);
        key = ICLTBase.StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });
        _updateStrategy(strategyID, key);
    }

    /// @notice Trails the position of strategy to both sides
    /// @param strategyID Hash of strategy ID
    /// @param key A51 strategy key details
    /// @return tickLower The lower tick of the range
    /// @return tickUpper The upper tick of the range
    function _shiftLeftAndRightBase(
        bytes32 strategyID,
        ICLTBase.StrategyKey memory key
    )
        internal
        returns (int24 tickLower, int24 tickUpper)
    {
        (tickLower, tickUpper) = shiftBothSide(key);
        key = ICLTBase.StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });
        _updateStrategy(strategyID, key);
    }

    /// @notice Internal function to update the position of strategy
    /// @param strategyID Hash of strategy ID
    /// @param newKey Ticks for new strategy position in pool
    function _updateStrategy(bytes32 strategyID, ICLTBase.StrategyKey memory newKey) internal {
        ICLTBase.ShiftLiquidityParams memory params = ICLTBase.ShiftLiquidityParams({
            key: newKey,
            strategyId: strategyID,
            shouldMint: true,
            zeroForOne: false,
            swapAmount: 0,
            moduleStatus: ""
        });

        baseVault.shiftLiquidity(params);
    }

    function updateTwapDuration(uint32 value) external onlyOwner {
        _twapDuration = value;
    }

    function _getStrategy(bytes32 strategyID)
        internal
        returns (ICLTBase.StrategyKey memory key, bytes memory actions)
    {
        (key,, actions,,,,,,) = baseVault.strategies(strategyID);
    }
}
