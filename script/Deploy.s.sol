// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "forge-std/Script.sol";
import "../src/CLTBase.sol";
import "../src/CLTModules.sol";
import "../src/utils/CLTHelper.sol";
import "../src/GovernanceFeeHandler.sol";
import "../src/interfaces/IGovernanceFeeHandler.sol";
import "../src/modules/rebasing/Modes.sol";
import "../src/modules/rebasing/RebaseModule.sol";

import { IAlgebraFactory } from "@cryptoalgebra/core/contracts/interfaces/IAlgebraFactory.sol";

contract DeployALP is Script {
    address _weth9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    IAlgebraFactory _factoryAddress = IAlgebraFactory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_2");
        vm.startBroadcast(deployerPrivateKey);

        CLTModules cltModules = new CLTModules();

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(feeParams, feeParams);

        CLTBase baseContract =
            new CLTBase("ALP_TOKEN", "ALPT", _weth9, address(feeHandler), address(cltModules), _factoryAddress);

        new CLTHelper();

        new Modes(address(baseContract));

        new RebaseModule(address(baseContract));

        vm.stopBroadcast();
    }
}
