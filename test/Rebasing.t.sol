// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "../src/CLTBase.sol";
import "../src/base/Structs.sol";
import "../src/modules/rebasing/Preference.sol";

contract RebasingModulesTest is Test {
    Vm hevm = Vm(HEVM_ADDRESS);

    address public WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public uniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public poolAddress = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

    IUniswapV3Factory uniswapV3FactoryContract = IUniswapV3Factory(uniswapV3Factory);
    IUniswapV3Pool poolContract = IUniswapV3Pool(poolAddress);

    bytes[] public exitStrategyData;
    bytes[] public rebasePreferenceData = [abi.encode(1, 2, 4, 5, 67, 8)];
    bytes[] public liquidityDistributionData;

    uint64[] public exitStrategy;
    uint64[] public rebasePreference = [1];
    uint64[] public liquidityDistribution;

    CLTBase public baseContract;
    RebasePreference public rebasePreferenceContrat;
    PositionActions public positionActionsData;
    ActionsData actionsData;

    function floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function setUp() public {
        baseContract = new CLTBase(
            "CLT TOKEN",
            "CLTT",
            address(this),
            WETH9,
            uniswapV3FactoryContract
        );

        rebasePreferenceContrat = new RebasePreference(address(baseContract), address(this));

        (, int24 tick,,,,,) = poolContract.slot0();

        int24 tickLower = floor(tick - 2000, poolContract.tickSpacing());
        int24 tickUpper = floor(tick + 2000, poolContract.tickSpacing());

        StrategyKey memory strategyKey;
        strategyKey.pool = poolContract;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;

        actionsData.exitStrategyData = exitStrategyData;
        actionsData.rebasePreferenceData = rebasePreferenceData;
        actionsData.liquidityDistributionData = liquidityDistributionData;

        positionActionsData.mode = 2;
        positionActionsData.exitStrategy = exitStrategy;
        positionActionsData.rebasePreference = rebasePreference;
        positionActionsData.liquidityDistribution = liquidityDistribution;

        baseContract.createStrategy(strategyKey, actionsData, positionActionsData, false);
    }

    function testCLTContractDeployment() public {
        bytes32 strategyID = baseContract.getStrategyId(address(this), 1);
        (StrategyKey memory key,,,,,,,) = baseContract.strategies(strategyID);

        (, int24 tick,,,,,) = poolContract.slot0();

        int24 tickLower = floor(tick - 2000, poolContract.tickSpacing());
        int24 tickUpper = floor(tick + 2000, poolContract.tickSpacing());

        assertEq(key.tickLower, tickLower);
        assertEq(key.tickUpper, tickUpper);
        assertEq(address(key.pool), address(poolContract));
    }

    function testCheckStrategies() public {
        bytes32 strategyID = baseContract.getStrategyId(address(this), 1);
        bytes32[] memory strategyIds = new bytes32[](1);
        strategyIds[0] = strategyID;

        (, int24 tick,,,,,) = poolContract.slot0();

        int24 tickLower = floor(tick - 2000, poolContract.tickSpacing());
        int24 tickUpper = floor(tick + 2000, poolContract.tickSpacing());

        StrategyKey memory strategyKey;
        strategyKey.pool = poolContract;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;

        rebasePreferenceData = [abi.encode(tickUpper + 4000, tickLower - 4000, 20, 30, 50, 50)];
        actionsData.rebasePreferenceData = rebasePreferenceData;
        baseContract.createStrategy(strategyKey, actionsData, positionActionsData, false);

        bytes32 strategyID2 = baseContract.getStrategyId(address(this), 2);
        console.logBytes32(strategyID);
        console.logBytes32(strategyID2);

        bytes32[] memory queue = rebasePreferenceContrat.checkStrategies(strategyIds);
        console.log(queue.length);
    }
}
