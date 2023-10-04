// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "../base/Structs.sol";

library Position {
    struct Data {
        bytes32 strategyId;
        uint256 liquidityShare;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
    }
}
