// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { CLTBase } from "../src/CLTBase.sol";
import { RebaseModule } from "../src/modules/rebasing/RebaseModule.sol";
import "../src/base/Structs.sol";

contract RebasingModulesTest is Test {
    Vm hevm = Vm(HEVM_ADDRESS);

    address public WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public uniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public poolAddress = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    // address public baseContractAddress = 0xCeA591CC4E4114cd4537B72e5640f0f60E9BCB10;
    // address public rebaseModuleContractAddress = 0xC4a2C558fDBeEF505105438e97A77A0073ecd792;
    address public owner = 0x97fF40b5678D2234B1E5C894b5F39b8BA8535431;

    IUniswapV3Factory uniswapV3FactoryContract = IUniswapV3Factory(uniswapV3Factory);
    IUniswapV3Pool poolContract = IUniswapV3Pool(poolAddress);

    StrategyKey public strategyKey;

    CLTBase public baseContract;
    RebaseModule public rebaseModuleContract;

    function setUp() public {
        baseContract = new CLTBase("ALP TOKEN", "ALPT", owner, WETH9, uniswapV3FactoryContract);
        rebaseModuleContract = new RebaseModule(owner,address(baseContract));
    }

    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function getStrategyKey() public {
        (, int24 tick,,,,,) = poolContract.slot0();

        int24 tickLower = _floor(tick, poolContract.tickSpacing());
        (tick - 2000, poolContract.tickSpacing());
        int24 tickUpper = _floor(tick + 2000, poolContract.tickSpacing());

        strategyKey.pool = poolContract;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;
    }

    function createStrategy(ActionDetails memory actionDetails) public { }

    function testRebaseDeploymentCheck() public {
        assertEq(rebaseModuleContract.isOperator(address(this)), false);
        hevm.prank(owner);
        rebaseModuleContract.toggleOperator(address(this));
        assertEq(rebaseModuleContract.isOperator(address(this)), true);
    }

    // Time preference
    function testCheckInputDataTimePreference() public {
        ActionDetails memory actionDetails;
        StrategyDetail[] memory details = new StrategyDetail[](1);

        getStrategyKey();

        details[0].actionName = keccak256("TIME_PREFERENCE");
        details[0].data = abi.encode(uint256(10));

        actionDetails.mode = 1;
        actionDetails.exitStrategy = new StrategyDetail[](0);
        actionDetails.rebaseStrategy = details;
        actionDetails.liquidityDistribution = new StrategyDetail[](0);

        hevm.prank(owner);
        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("TIME_PREFERENCE"), address(rebaseModuleContract)
        );

        bytes4 selector = bytes4(keccak256("InvalidTimePreference()"));
        hevm.expectRevert(selector);
        baseContract.createStrategy(strategyKey, actionDetails, true);

        details[0].data = abi.encode(uint256(31_537_000));

        actionDetails.rebaseStrategy = details;

        selector = bytes4(keccak256("InvalidTimePreference()"));
        hevm.expectRevert(selector);
        baseContract.createStrategy(strategyKey, actionDetails, true);
    }

    function testCheckInputDataTimePreferenceWithZeroData() public {
        getStrategyKey();
        ActionDetails memory actionDetails;
        StrategyDetail[] memory details = new StrategyDetail[](1);

        hevm.prank(owner);
        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("TIME_PREFERENCE"), address(rebaseModuleContract)
        );

        details[0].actionName = keccak256("TIME_PREFERENCE");
        details[0].data = abi.encode(uint256(0));

        actionDetails.mode = 1;
        actionDetails.exitStrategy = new StrategyDetail[](0);
        actionDetails.rebaseStrategy = details;
        actionDetails.liquidityDistribution = new StrategyDetail[](0);

        bytes4 selector = bytes4(keccak256("RebaseStrategyDataCannotBeZero()"));
        hevm.expectRevert(selector);
        baseContract.createStrategy(strategyKey, actionDetails, true);
    }

    function testCheckInputDataTimePreferenceWithRebaseInactivity() public {
        getStrategyKey();
        ActionDetails memory actionDetails;
        StrategyDetail[] memory details = new StrategyDetail[](2);

        details[0].actionName = keccak256("TIME_PREFERENCE");
        details[0].data = abi.encode(uint256(block.timestamp + 1000));

        details[1].actionName = keccak256("REBASE_INACTIVITY");
        details[1].data = abi.encode(uint256(2));

        actionDetails.mode = 1;
        actionDetails.exitStrategy = new StrategyDetail[](0);
        actionDetails.rebaseStrategy = details;
        actionDetails.liquidityDistribution = new StrategyDetail[](0);

        hevm.prank(owner);
        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("TIME_PREFERENCE"), address(rebaseModuleContract)
        );

        hevm.prank(owner);
        baseContract.addModule(
            keccak256("REBASE_STRATEGY"), keccak256("REBASE_INACTIVITY"), address(rebaseModuleContract)
        );

        baseContract.createStrategy(strategyKey, actionDetails, true);
    }
}
