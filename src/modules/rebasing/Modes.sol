// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ICLTBase } from "../../interfaces/ICLTBase.sol";
import { AccessControl } from "../../base/AccessControl.sol";
import { ModeTicksCalculation } from "../../base/ModeTicksCalculation.sol";
import { console } from "forge-std/console.sol";

contract Modes is ModeTicksCalculation, AccessControl {
    error InvalidModeId(uint256 modeId);
    error InvalidStrategyId(bytes32 strategyID);

    ICLTBase public baseVault;

    constructor(address vault, address owner) AccessControl(owner) {
        baseVault = ICLTBase(vault);
    }

    function ShiftBase(bytes32[] calldata strategyIDs) external returns (int24 tickLower, int24 tickUpper) {
        uint256 strategyIdsLength = strategyIDs.length;

        for (uint256 i = 0; i < strategyIdsLength; i++) {
            (ICLTBase.StrategyKey memory key, bytes memory actions) = getStrategy(strategyIDs[i]);

            if (address(key.pool) == address(0)) revert InvalidStrategyId(strategyIDs[i]);
            ICLTBase.PositionActions memory modules = abi.decode(actions, (ICLTBase.PositionActions));

            if (modules.mode == 1) {
                (tickLower, tickUpper) = shiftLeftBase(strategyIDs[i], key);
            } else if (modules.mode == 2) {
                (tickLower, tickUpper) = shiftRightBase(strategyIDs[i], key);
            } else if (modules.mode == 3) {
                (tickLower, tickUpper) = shiftLeftAndRightBase(strategyIDs[i], key);
            } else {
                revert InvalidModeId(modules.mode);
            }
        }
    }

    function shiftLeftBase(
        bytes32 strategyID,
        ICLTBase.StrategyKey memory key
    )
        internal
        returns (int24 tickLower, int24 tickUpper)
    {
        (tickLower, tickUpper) = shiftLeft(key);
        key = ICLTBase.StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });
        updateStrategy(strategyID, key);
    }

    function shiftRightBase(
        bytes32 strategyID,
        ICLTBase.StrategyKey memory key
    )
        internal
        returns (int24 tickLower, int24 tickUpper)
    {
        (tickLower, tickUpper) = shiftRight(key);
        key = ICLTBase.StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });
        updateStrategy(strategyID, key);
    }

    function shiftLeftAndRightBase(
        bytes32 strategyID,
        ICLTBase.StrategyKey memory key
    )
        internal
        returns (int24 tickLower, int24 tickUpper)
    {
        (tickLower, tickUpper) = shiftBothSide(key);
        key = ICLTBase.StrategyKey({ pool: key.pool, tickLower: tickLower, tickUpper: tickUpper });
        updateStrategy(strategyID, key);
    }

    function getStrategy(bytes32 strategyID) internal returns (ICLTBase.StrategyKey memory key, bytes memory actions) {
        (key,, actions,,,,,,) = baseVault.strategies(strategyID);
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
