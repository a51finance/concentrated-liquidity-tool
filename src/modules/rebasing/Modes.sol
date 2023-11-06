// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

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
        (ICLTBase.StrategyKey memory key, bytes memory actions) = getStrategy(strategyID);

        ICLTBase.PositionActions memory modules = abi.decode(actions, (ICLTBase.PositionActions));

        if (modules.mode == 1) {
            (tickLower, tickUpper) = shiftLeft(key, 10);

            key = ICLTBase.StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });

            updateStrategy(strategyID, key);
        } else {
            revert InvalidModeId(modules.mode);
        }
    }

    function shiftRight(bytes32 strategyID) external onlyOperator returns (int24 tickLower, int24 tickUpper) {
        (ICLTBase.StrategyKey memory key, bytes memory actions) = getStrategy(strategyID);

        ICLTBase.PositionActions memory modules = abi.decode(actions, (ICLTBase.PositionActions));

        if (modules.mode == 2) {
            (tickLower, tickUpper) = shiftRight(key, 10);

            key = ICLTBase.StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });

            updateStrategy(strategyID, key);
        } else {
            revert InvalidModeId(modules.mode);
        }
    }

    function shiftLeftAndRight(bytes32 strategyID) external onlyOperator returns (int24 tickLower, int24 tickUpper) {
        (ICLTBase.StrategyKey memory key, bytes memory actions) = getStrategy(strategyID);

        ICLTBase.PositionActions memory modules = abi.decode(actions, (ICLTBase.PositionActions));

        if (modules.mode == 3) {
            (tickLower, tickUpper) = shiftBothSide(key, 10);

            key = ICLTBase.StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });

            updateStrategy(strategyID, key);
        } else {
            revert InvalidModeId(modules.mode);
        }
    }

    function getStrategy(bytes32 strategyID) internal returns (ICLTBase.StrategyKey memory key, bytes memory actions) {
        (key, actions,,,,,,,,) = baseVault.strategies(strategyID);
    }

    function updateStrategy(bytes32 strategyID, ICLTBase.StrategyKey memory newKey) internal {
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
}
