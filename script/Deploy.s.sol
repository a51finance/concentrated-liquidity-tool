// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "forge-std/Script.sol";
import "../src/CLTBase.sol";
import "../src/CLTModules.sol";
import "../src/CLTTwapQuoter.sol";
import "../src/utils/CLTHelper.sol";
import "../src/GovernanceFeeHandler.sol";
import "../src/interfaces/IGovernanceFeeHandler.sol";
import "../src/modules/rebasing/Modes.sol";
import "../src/modules/rebasing/RebaseModule.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract DeployALP is Script {
    // address _owner = 0x97fF40b5678D2234B1E5C894b5F39b8BA8535431;
    // address _weth9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    // mainnet
    address _owner = 0x4eF03f0eA9e744F22B768E17628cE39a2f48AbE5;
    address _weth9 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    IUniswapV3Factory _factoryAddress = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_MAIN");
        vm.startBroadcast(deployerPrivateKey);

        new CLTHelper();
        CLTModules cltModules = new CLTModules();
        CLTTwapQuoter twapQuoter = new CLTTwapQuoter();

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(feeParams, feeParams);

        CLTBase baseContract = new CLTBase(
            "A51 Liquidity Positions NFT", "ALPhy", _weth9, address(feeHandler), address(cltModules), _factoryAddress
        );

        new Modes(address(baseContract), address(twapQuoter));
        new RebaseModule(_owner, address(baseContract), address(twapQuoter));

        vm.stopBroadcast();
    }
}
