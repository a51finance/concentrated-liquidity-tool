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

// forge test --fork-url polygon --fork-block-number 52079930 -vvvv --match-test ""
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

    function testContractAddresses() public view {
        console.log("Base Contract", address(base));
        console.log("Rebase Module Contract", address(rebaseModule));
        console.log("Modules Contract", address(cltModules));
    }

    function test_mainnet_deposit() public {
        ICLTBase.StrategyPayload[] memory rebaseActions = new ICLTBase.StrategyPayload[](1);
        rebaseActions[0].actionName = rebaseModule.PRICE_PREFERENCE();
        rebaseActions[0].data = abi.encode(10, 30);

        ICLTBase.PositionActions memory positionActions;
        positionActions.mode = 1;
        positionActions.exitStrategy = new ICLTBase.StrategyPayload[](0);
        positionActions.rebaseStrategy = rebaseActions;
        positionActions.liquidityDistribution = new ICLTBase.StrategyPayload[](0);

        initStrategy(450);

        _hevm.prank(owner0);
        base.createStrategy(strategyKey, positionActions, 0, 0, true, false);

        bytes32 strategyID = getStrategyID(owner0, 1);

        ICLTBase.DepositParams memory depositParams;
        depositParams.strategyId = strategyID;
        depositParams.amount0Desired = 100e6;
        depositParams.amount1Desired = 1e18;
        depositParams.amount0Min = 0;
        depositParams.amount1Min = 0;
        depositParams.recipient = owner0;

        _hevm.prank(owner0);
        base.deposit(depositParams);

        (, uint256 liquidityShare,,,,) = base.positions(1);
        assertEq(liquidityShare, 1_000_000_000_000_000_000);
    }
}
