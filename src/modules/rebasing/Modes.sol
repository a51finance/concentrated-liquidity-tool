// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { StrategyKey, ShiftLiquidityParams, PositionActions } from "../../base/Structs.sol";
import { ICLTBase } from "../../interfaces/ICLTBase.sol";
import { AccessControl } from "../../base/AccessControl.sol";
import { ModeTicksCalculation } from "../../base/ModeTicksCalculation.sol";

contract Modes is ModeTicksCalculation, AccessControl {
    error InvalidModeId(uint256 modeId);

    ICLTBase public baseVault;

    constructor(ICLTBase vault, address owner) AccessControl(owner) {
        baseVault = ICLTBase(vault);
    }

    function shiftLeft(bytes32 strategyID) external onlyOperator returns (int24 tickLower, int24 tickUpper) {
        (StrategyKey memory key, bytes memory actions) = getStrategy(strategyID);

        PositionActions memory modules = abi.decode(actions, (PositionActions));

        if (modules.mode == 1) {
            (tickLower, tickUpper) = shiftLeft(key);

            key = StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });

            updateStrategy(strategyID, key);
        } else {
            revert InvalidModeId(modules.mode);
        }
    }

    function shiftRight(bytes32 strategyID) external onlyOperator returns (int24 tickLower, int24 tickUpper) {
        (StrategyKey memory key, bytes memory actions) = getStrategy(strategyID);

        PositionActions memory modules = abi.decode(actions, (PositionActions));

        if (modules.mode == 2) {
            (tickLower, tickUpper) = shiftRight(key);

            key = StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });

            updateStrategy(strategyID, key);
        } else {
            revert InvalidModeId(modules.mode);
        }
    }

    function shiftLeftAndRight(bytes32 strategyID) external onlyOperator returns (int24 tickLower, int24 tickUpper) {
        (StrategyKey memory key, bytes memory actions) = getStrategy(strategyID);

        PositionActions memory modules = abi.decode(actions, (PositionActions));

        if (modules.mode == 3) {
            (tickLower, tickUpper) = shiftBothSide(key);

            key = StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });

            updateStrategy(strategyID, key);
        } else {
            revert InvalidModeId(modules.mode);
        }
    }

    function getStrategy(bytes32 strategyID) internal returns (StrategyKey memory key, bytes memory actions) {
        (key, actions,,,,,,,,,) = baseVault.strategies(strategyID);
    }

    function updateStrategy(bytes32 strategyID, StrategyKey memory newKey) internal {
        ShiftLiquidityParams memory params = ShiftLiquidityParams({
            key: newKey,
            strategyId: strategyID,
            shouldMint: true,
            zeroForOne: false,
            swapAmount: 0,
            moduleStatus: ""
        });

        baseVault.shiftLiquidity(params);
    }
}
