// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

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
    address _weth9 = 0x0Dc808adcE2099A9F62AA87D9670745AbA741746;

    IUniswapV3Factory _factoryAddress = IUniswapV3Factory(0x56c2162254b0E4417288786eE402c2B41d4e181e);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_MAIN");
        vm.startBroadcast(deployerPrivateKey);

        new CLTHelper();
        // CLTModules cltModules = new CLTModules(_owner);
        // CLTTwapQuoter twapQuoter = new CLTTwapQuoter(_owner);

        // IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
        //     lpAutomationFee: 0,
        //     strategyCreationFee: 0,
        //     protcolFeeOnManagement: 0,
        //     protcolFeeOnPerformance: 0
        // });

        // GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(_owner, feeParams, feeParams);

        // CLTBase baseContract = new CLTBase(
        //     "A51 Liquidity Positions NFT",
        //     "ALPhy",
        //     _owner,
        //     _weth9,
        //     address(feeHandler),
        //     address(cltModules),
        //     _factoryAddress
        // );

        // new Modes(address(baseContract), address(twapQuoter), _owner);
        // new RebaseModule(_owner, address(baseContract), address(twapQuoter));

        vm.stopBroadcast();
    }
}
