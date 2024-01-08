// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { MainnetFixtures } from "./utils/MainnetFixtures.sol";
import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { Test } from "forge-std/Test.sol";
import { IQuoter } from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import { console } from "forge-std/console.sol";
import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { Constants } from "./utils/Constants.sol";

contract MainnetForkTest is Test, MainnetFixtures {
    address owner0;
    address owner1;

    function setUp() public {
        owner0 = 0x9dd1B9fD454c059ABbA14C32f16fb93bf579A4Ca; // own eth and matic
        owner1 = 0x0E297fB0b39514819fe8fF7D2F82226b655F3658; //owns usdc and matic
        _hevm.prank(owner1);
        ERC20Mock(Constants.USDC).transfer(owner0, 147_207_553_210);
        initBase(owner0);
    }

    // forge test --fork-url polygon --fork-block-number 52079930 -vvvv --match-test "testContractAddresses"
    function testContractAddresses() public view {
        console.log("Base Contract", address(base));
        console.log("Rebase Module Contract", address(rebaseModule));
        console.log("Modules Contract", address(cltModules));
    }
}
