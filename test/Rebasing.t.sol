// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../src/CLTBase.sol";
import "../src/base/Structs.sol";
import "../src/modules/rebasing/RebaseModule.sol";

contract RebasingModulesTest is Test {
    Vm _hevm = Vm(HEVM_ADDRESS);

    address public WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public uniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public poolAddress = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address public baseContractAddress = 0xCeA591CC4E4114cd4537B72e5640f0f60E9BCB10;
    address public rebaseModuleContractAddress = 0xC4a2C558fDBeEF505105438e97A77A0073ecd792;
    address public owner = 0x97fF40b5678D2234B1E5C894b5F39b8BA8535431;

    IUniswapV3Factory uniswapV3FactoryContract = IUniswapV3Factory(uniswapV3Factory);
    IUniswapV3Pool poolContract = IUniswapV3Pool(poolAddress);

    StrategyKey public strategyKey;

    CLTBase public baseContract;
    RebaseModule public rebaseModuleContract;
    PositionActions public positionActionsData;
    ActionsData actionsData;

    function setUp() public {
        baseContract = new CLTBase("ALP TOKEN", "ALPT", owner,WETH9,uniswapV3FactoryContract);
        rebaseModuleContract = new RebaseModule(owner,address(baseContract));
    }

    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function testRebaseDeploymentCheck() public {
        assertEq(rebaseModuleContract.isOperator(address(this)), false);
        _hevm.prank(owner);
        rebaseModuleContract.toggleOperator(address(this));
        assertEq(rebaseModuleContract.isOperator(address(this)), true);
    }

    function testCheckAndProcessStrategies() public {
        (, int24 tick,,,,,) = poolContract.slot0();

        int24 tickLower = _floor(tick, poolContract.tickSpacing());
        (tick - 2000, poolContract.tickSpacing());
        int24 tickUpper = _floor(tick + 2000, poolContract.tickSpacing());

        strategyKey.pool = poolContract;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;

        bytes[] memory values = new bytes[](3);
        values[0] = abi.encode(int24(10), int24(10));
        values[1] = new bytes(0); // Initialize with an empty byte array
        values[2] = new bytes(0); // Initialize with an empty byte array

        actionsData.exitStrategyData = new bytes[](0);
        actionsData.rebaseStrategyData = values;
        actionsData.liquidityDistributionData = new bytes[](0);

        positionActionsData.mode = 1;
        positionActionsData.exitStrategy = new uint256[](0);
        positionActionsData.rebaseStrategy = [1, 0, 0];
        positionActionsData.liquidityDistribution = new uint256[](0);

        uint64[] memory newModule = new uint64[](3);
        newModule[0] = 1;
        newModule[1] = 2;
        newModule[2] = 3;

        _hevm.prank(owner);
        baseContract.addModule(
            0x5eea0aea3d82798e316d046946dbce75c9d5995b956b9e60624a080c7f56f204, address(baseContract), newModule
        );

        // baseContract.createStrategy(strategyKey, actionsData, positionActionsData, true);
    }
}
