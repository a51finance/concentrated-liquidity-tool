// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.15;

import { ICLTBase } from "../interfaces/ICLTBase.sol";

contract CLTHelper {
    function decodePositionActions(bytes memory actions) external pure returns (ICLTBase.PositionActions memory) {
        ICLTBase.PositionActions memory modules = abi.decode(actions, (ICLTBase.PositionActions));
        return modules;
    }
}
