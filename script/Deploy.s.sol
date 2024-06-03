// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "../src/CLTBase.sol";
import "../src/CLTModules.sol";
import "../src/CLTTwapQuoter.sol";
// import "../src/utils/CLTHelper.sol";
import "../src/GovernanceFeeHandler.sol";
import "../src/interfaces/IGovernanceFeeHandler.sol";
import "../src/modules/rebasing/Modes.sol";
import "../src/modules/rebasing/RebaseModule.sol";
import "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol";

contract DeployALP is Script {
    address owner = 0x4eF03f0eA9e744F22B768E17628cE39a2f48AbE5;

    // polygon mainnet
    // address _weth = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    // IAlgebraFactory _factoryAddress = IAlgebraFactory(0x411b0fAcC3489691f28ad58c47006AF5E3Ab3A28);

    // polygon zkEVM
    // address _weth = 0x4F9A0e7FD2Bf6067db6994CF12E4495Df938E6e9;
    // IAlgebraFactory _factoryAddress = IAlgebraFactory(0x4B9f4d2435Ef65559567e5DbFC1BbB37abC43B57);

    // linea (algebra v1.9)
    address _weth9 = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    IAlgebraFactory _factoryAddress = IAlgebraFactory(0x622b2c98123D303ae067DB4925CD6282B3A08D0F);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // new CLTHelper();
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
