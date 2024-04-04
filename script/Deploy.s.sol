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
    address _weth9 = 0x4300000000000000000000000000000000000004;
    address _pointsAdmin = 0x357aF75C3D954Fb9DD7ae9821AA53Cd3f6F1D9f7;

    IUniswapV3Factory _factoryAddress = IUniswapV3Factory(0x792edAdE80af5fC680d96a2eD80A44247D2Cf6Fd);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_MAIN");
        vm.startBroadcast(deployerPrivateKey);

        new CLTHelper();
        CLTModules cltModules = new CLTModules(_owner);
        CLTTwapQuoter twapQuoter = new CLTTwapQuoter(_owner);

        IGovernanceFeeHandler.ProtocolFeeRegistry memory feeParams = IGovernanceFeeHandler.ProtocolFeeRegistry({
            lpAutomationFee: 0,
            strategyCreationFee: 0,
            protcolFeeOnManagement: 0,
            protcolFeeOnPerformance: 0
        });

        GovernanceFeeHandler feeHandler = new GovernanceFeeHandler(_owner, feeParams, feeParams);

        CLTBase baseContract = new CLTBase(
            "A51 Liquidity Positions NFT",
            "ALPhy",
            _owner,
            _weth9,
            address(feeHandler),
            address(cltModules),
            _pointsAdmin,
            _factoryAddress
        );

        new Modes(address(baseContract), address(twapQuoter), _owner);
        new RebaseModule(_owner, address(baseContract), address(twapQuoter));

        vm.stopBroadcast();
    }
}
