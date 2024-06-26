// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "../src/CLTBase.sol";
import "../src/CLTModules.sol";
import "../src/CLTTwapQuoter.sol";
import { CLTHelper } from "../src/utils/CLTHelper.sol";
import "../src/GovernanceFeeHandler.sol";
import "../src/interfaces/IGovernanceFeeHandler.sol";
import "../src/modules/rebasing/Modes.sol";
import "../src/modules/rebasing/RebaseModule.sol";
import "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol";

contract DeployALP is Script {
    address owner = 0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89;
    address _weth9 = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;
    IAlgebraFactory _factoryAddress = IAlgebraFactory(0x6AD6A4f233F1E33613e996CCc17409B93fF8bf5f);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new CLTHelper();
        CLTModules cltModules = new CLTModules(owner);
        CLTTwapQuoter twapQuoter = new CLTTwapQuoter(owner);

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(feeParams, feeParams);

        CLTBase baseContract = new CLTBase(
            "A51 Liquidity Positions NFT",
            "ALPhy",
            owner,
            _weth9,
            address(feeHandler),
            address(cltModules),
            _factoryAddress
        );

        new Modes(owner, address(baseContract), address(twapQuoter));
        new RebaseModule(owner, address(baseContract), address(twapQuoter));

        vm.stopBroadcast();
    }
}
