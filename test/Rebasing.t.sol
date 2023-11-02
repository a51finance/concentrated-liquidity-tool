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

    // check input data test cases
    // Price preference

    function testInputDataPricePreferenceWithValidInputs() public view {
        StrategyDetail memory strategyDetail;
        strategyDetail.actionName = rebaseModuleContract.PRICE_PREFERENCE();
        strategyDetail.data = abi.encode(uint256(10), uint256(30));
        rebaseModuleContract.checkInputData(strategyDetail);

        strategyDetail.data = abi.encode(uint256(203_247), uint256(10_000));
        rebaseModuleContract.checkInputData(strategyDetail);
    }

    function testInputDataPricePreferenceWithInValidInputs() public {
        StrategyDetail memory strategyDetail;
        strategyDetail.actionName = rebaseModuleContract.PRICE_PREFERENCE();
        strategyDetail.data = abi.encode(uint256(0), uint256(30));

        bytes4 selector = bytes4(keccak256("InvalidPricePreferenceDifference()"));
        hevm.expectRevert(selector);
        rebaseModuleContract.checkInputData(strategyDetail);

        strategyDetail.data = abi.encode(uint256(0), uint256(0));

        selector = bytes4(keccak256("RebaseStrategyDataCannotBeZero()"));
        hevm.expectRevert(selector);
        rebaseModuleContract.checkInputData(strategyDetail);
    }

    // Time preference

    function testCheckInputDataTimePreferenceWithValidInputs() public view {
        StrategyDetail memory strategyDetail;
        strategyDetail.data = abi.encode(uint256(block.timestamp + 3600));
        strategyDetail.actionName = rebaseModuleContract.TIME_PREFERENCE();
        rebaseModuleContract.checkInputData(strategyDetail);
    }

    function testCheckInputDataTimePreferenceWithInvalidInputs() public {
        StrategyDetail memory strategyDetail;
        strategyDetail.data = abi.encode(uint256(block.timestamp));
        strategyDetail.actionName = rebaseModuleContract.TIME_PREFERENCE();

        bytes4 selector = bytes4(keccak256("InvalidTimePreference()"));
        hevm.expectRevert(selector);
        rebaseModuleContract.checkInputData(strategyDetail);

        strategyDetail.data = abi.encode(uint256(0));
        selector = bytes4(keccak256("RebaseStrategyDataCannotBeZero()"));
        hevm.expectRevert(selector);
        rebaseModuleContract.checkInputData(strategyDetail);

        strategyDetail.data = abi.encode(uint256(block.timestamp + 31_537_000));
        selector = bytes4(keccak256("InvalidTimePreference()"));
        hevm.expectRevert(selector);
        rebaseModuleContract.checkInputData(strategyDetail);
    }

    // Rebase Inactivity

    function testInputDataRebaseInActivityWithValidInputs() public {
        StrategyDetail memory strategyDetail;
        strategyDetail.data = abi.encode(uint256(2));
        strategyDetail.actionName = rebaseModuleContract.REBASE_INACTIVITY();

        rebaseModuleContract.checkInputData(strategyDetail);
    }

    function testInputDataRebaseInActivityWithInValidInputs() public {
        StrategyDetail memory strategyDetail;
        strategyDetail.actionName = rebaseModuleContract.REBASE_INACTIVITY();
        strategyDetail.data = abi.encode(uint256(0));

        bytes4 selector = bytes4(keccak256("RebaseInactivityCannotBeZero()"));
        hevm.expectRevert(selector);
        rebaseModuleContract.checkInputData(strategyDetail);
    }
}
