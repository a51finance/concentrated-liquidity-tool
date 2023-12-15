// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import "forge-std/Script.sol";
import "../src/CLTBase.sol";
import "../src/CLTModules.sol";
import "../src/utils/CLTHelper.sol";
import "../src/GovernanceFeeHandler.sol";
import "../src/interfaces/IGovernanceFeeHandler.sol";
import "../src/modules/rebasing/Modes.sol";
import "../src/modules/rebasing/RebaseModule.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract DeployALP is Script {
    address _owner = 0x97fF40b5678D2234B1E5C894b5F39b8BA8535431;
    address _weth9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    // mainnet
    // address _owner = 0x9De199457b5F6e4690eac92c399A0Cd31B901Dc3;
    // address _weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IUniswapV3Factory _factoryAddress = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_2");
        vm.startBroadcast(deployerPrivateKey);

        CLTModules cltModules = new CLTModules(_owner);

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(_owner, feeParams, feeParams);

        new CLTBase("ALP_TOKEN", "ALPT", _owner,_weth9, address(feeHandler), address(cltModules),
        _factoryAddress);

        new CLTHelper();

        vm.stopBroadcast();
    }
}

contract DeployRebaseModule is Script {
    address _owner = 0x97fF40b5678D2234B1E5C894b5F39b8BA8535431;
    address _baseContract = 0x63fb6c5145F28Fab88F08A725cc305828aEA01eC;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_2");
        vm.startBroadcast(deployerPrivateKey);

        new Modes(_baseContract,_owner);
        // new RebaseModule(_owner,_baseContract);

        vm.stopBroadcast();
    }
}
