// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import { Test } from "forge-std/Test.sol";
import { Fixtures } from "./utils/Fixtures.sol";

import { ICLTBase } from "../src/interfaces/ICLTBase.sol";
import { ICLTModules } from "../src/interfaces/ICLTModules.sol";
import { IRebaseStrategy } from "../src/interfaces/modules/IRebaseStrategy.sol";
import { IGovernanceFeeHandler } from "../src/interfaces/IGovernanceFeeHandler.sol";

contract FeeHandlerTest is Test, Fixtures { }
