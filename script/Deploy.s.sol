// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "forge-std/Script.sol";
import "../src/CLTBase.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract DeployALP is Script {
    address _owner = 0x97fF40b5678D2234B1E5C894b5F39b8BA8535431;
    address _weth9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    IUniswapV3Factory _factoryAddress = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        CLTBase baseContract = new CLTBase("ALP_TOKEN", "ALPT", _owner,_weth9, _factoryAddress);

        vm.stopBroadcast();
    }
}
