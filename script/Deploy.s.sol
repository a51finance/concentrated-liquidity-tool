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
    address _owner = 0x4eF03f0eA9e744F22B768E17628cE39a2f48AbE5;
    address _weth9 = 0x0Dc808adcE2099A9F62AA87D9670745AbA741746;

    address baseFactory = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address _weth9Base = 0x4200000000000000000000000000000000000006;

    address bnbFactory = 0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7;
    address _weth9bnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address polygonOptimismFactory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address _wmatic = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address _weth9Optimism = 0x4200000000000000000000000000000000000006;

    address scrollFactory = 0x70C62C8b8e801124A4Aa81ce07b637A3e83cb919;
    address scrollWeth = 0x5300000000000000000000000000000000000004;

    address baseSwapFactory = 0x38015D05f4fEC8AFe15D7cc0386a126574e8077B;
    address baseWeth9 = 0x4200000000000000000000000000000000000006;

    address cltbaseArbitrum = 0x3e0AA2e17FE3E5e319f388C794FdBC3c64Ef9da6;

    address aerodromFactory = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    // Holesky testnet
    address _ownerSepolia = 0x9De199457b5F6e4690eac92c399A0Cd31B901Dc3;
    address _weth9Sepolia = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address _sepoliaFactory = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;

    IUniswapV3Factory _factoryInterface = IUniswapV3Factory(aerodromFactory);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_MAIN");
        vm.startBroadcast(deployerPrivateKey);

        // new CLTHelper();
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
            _weth9Base,
            address(feeHandler),
            address(cltModules),
            _factoryInterface
        );

        new Modes(address(baseContract), address(twapQuoter), _owner);
        // new RebaseModule(_owner, address(baseContract), address(twapQuoter));

        vm.stopBroadcast();
    }
}
