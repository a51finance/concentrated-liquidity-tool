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
    // address _owner = 0x97fF40b5678D2234B1E5C894b5F39b8BA8535431;
    // address _weth9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    // mainnet
    address _owner = 0x9De199457b5F6e4690eac92c399A0Cd31B901Dc3;
    address _weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IUniswapV3Factory _factoryAddress = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // CLTModules cltModules = new CLTModules(_owner);

        // IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
        //     lpAutomationFee: 0,
        //     strategyCreationFee: 0,
        //     protcolFeeOnManagement: 0,
        //     protcolFeeOnPerformance: 0
        // });

        // GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(_owner, feeParams, feeParams);

        CLTBase baseContract = new CLTBase("ALP_TOKEN", "ALPT", _owner,_weth9, address(0xf2bBec7C8A7eb3D703f38618e16c6E0369010b97),
        address(0xC88476C909EFa1853a44Ca12f0370929c7812dd8),
        _factoryAddress);

        new CLTHelper();

        new Modes(address(baseContract),_owner);

        new RebaseModule(_owner,address(baseContract));

        vm.stopBroadcast();
    }
}

// contract SetUpContract is Script {
//     address _owner = 0x97fF40b5678D2234B1E5C894b5F39b8BA8535431;
//     address _baseContract = 0x30eD7AFE5083B170884eC959cb4d7CE1b757aD59;
//     address _modulesContract = 0x8402Aebbc0b1b62c8c9F7AFafE95467394414711;
//     address _rebaseModule = 0x8b23A5008303D31f709009FF99794389ed04A8b9;

//     function run() external {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_2");
//         vm.startBroadcast(deployerPrivateKey);

//         CLTModules cltModules = CLTModules(_modulesContract);
//         RebaseModule rebaseModules = RebaseModule(_rebaseModule);
//         CLTBase baseContract = CLTBase(_baseContract);

//         cltModules.setNewModule(keccak256("REBASE_STRATEGY"), rebaseModules.PRICE_PREFERENCE());
//         cltModules.setNewModule(keccak256("REBASE_STRATEGY"), rebaseModules.REBASE_INACTIVITY());
//         cltModules.setModuleAddress(keccak256("REBASE_STRATEGY"), address(rebaseModules));

//         vm.stopBroadcast();
//     }
// }
