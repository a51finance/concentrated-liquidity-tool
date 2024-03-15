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
    // mainnet
    // address _owner = 0x9De199457b5F6e4690eac92c399A0Cd31B901Dc3;
    // address _weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // arbitrum
    address _owner = 0x9De199457b5F6e4690eac92c399A0Cd31B901Dc3;
    address _weth9 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    IUniswapV3Factory _factoryAddress = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_2");
        vm.startBroadcast(deployerPrivateKey);

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
        //     "ALP_TOKEN",
        //     "ALPT",
        //     _owner,
        //     _weth9,
        //     address(0x40E865434505c52577ccE34624C79bf840FdAa3A),
        //     address(0x74226579ED541adA94582DC4cD6DDd21f6526863),
        //     _factoryAddress
        // );

        // new CLTHelper();
        new Modes(
            address(0x4dBAcAA91e441598d8AFE4e8672E46E4e65910D0),
            address(0x6bf322e9db8b725E840dAc6fe403B923003584A0),
            _owner
        );
        new RebaseModule(
            _owner,
            address(0x4dBAcAA91e441598d8AFE4e8672E46E4e65910D0),
            address(0x6bf322e9db8b725E840dAc6fe403B923003584A0)
        );

        vm.stopBroadcast();
    }
}
