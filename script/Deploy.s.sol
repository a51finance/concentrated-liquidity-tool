// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import "forge-std/Script.sol";
import "../src/CLTBase.sol";
import "../src/CLTModules.sol";
import "../src/GovernanceFeeHandler.sol";
import "../src/interfaces/IGovernanceFeeHandler.sol";
import "../src/modules/rebasing/RebaseModule.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract DeployALP is Script {
    address _owner = 0x97fF40b5678D2234B1E5C894b5F39b8BA8535431;
    address _weth9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    IUniswapV3Factory _factoryAddress = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        CLTModules cltModules = new CLTModules(address(this));

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(address(this), feeParams, feeParams);

        CLTBase baseContract =
            new CLTBase("ALP_TOKEN", "ALPT", _owner,_weth9, address(feeHandler), address(cltModules), _factoryAddress);

        vm.stopBroadcast();
    }
}

contract DeployRebaseModule is Script {
    address _owner = 0x97fF40b5678D2234B1E5C894b5F39b8BA8535431;
    address _baseContract = 0x08c868F6424269B73287fc82109A4c631aae6407;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        RebaseModule rebaseModule = new RebaseModule(_owner,_baseContract);

        vm.stopBroadcast();
    }
}
