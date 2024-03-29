// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "forge-std/Script.sol";
import "../src/CLTBase.sol";
import "../src/CLTModules.sol";
import "../src/CLTTwapQuoter.sol";
// import "../src/utils/CLTHelper.sol";
import "../src/GovernanceFeeHandler.sol";
import "../src/interfaces/IGovernanceFeeHandler.sol";
import "../src/modules/rebasing/Modes.sol";
import "../src/modules/rebasing/RebaseModule.sol";

import { IAlgebraFactory } from "@cryptoalgebra/core/contracts/interfaces/IAlgebraFactory.sol";

contract DeployALP is Script {
    address _weth9 = 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889;

    IAlgebraFactory _factoryAddress = IAlgebraFactory(0x9cE372C452d8621fB891EA65456A51e5e4863F4C);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        CLTModules cltModules = new CLTModules();
        CLTTwapQuoter twapQuoter = new CLTTwapQuoter();

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(feeParams, feeParams);

        CLTBase baseContract =
            new CLTBase("ALP_TOKEN", "ALPT", _weth9, address(feeHandler), address(cltModules), _factoryAddress);

        // new CLTHelper();
        new Modes(address(baseContract), address(twapQuoter));
        new RebaseModule(address(baseContract), address(twapQuoter));

        vm.stopBroadcast();
    }
}
