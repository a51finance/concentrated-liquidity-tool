// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { ERC20Mock } from "../mocks/ERC20Mock.sol";

contract Fixtures {
    function deployTokens(uint8 count, uint256 totalSupply) public returns (ERC20Mock[] memory tokens) {
        tokens = new ERC20Mock[](count);
        for (uint8 i = 0; i < count; i++) {
            tokens[i] = new ERC20Mock();
            tokens[i].mint(msg.sender, totalSupply);
        }
    }
}
