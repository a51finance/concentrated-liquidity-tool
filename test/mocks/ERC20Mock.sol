// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.15;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20("Test Token", "Test") {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
