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
    Vm _hevm = Vm(HEVM_ADDRESS);

    address public WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public uniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public poolAddress = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

    IUniswapV3Factory uniswapV3FactoryContract = IUniswapV3Factory(uniswapV3Factory);
    IUniswapV3Pool poolContract = IUniswapV3Pool(poolAddress);

    StrategyKey public strategyKey;

    CLTBase public baseContract;
    RebasePreference public rebasePreferenceContrat;
    PositionActions public positionActionsData;
    ActionsData actionsData;

    function floor(int24 tick, int24 tickSpacing) public pure returns (int24) {
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
    }

    function createBaseContractStrategy(
        bytes[] memory _exitStrategyData,
        bytes[] memory _rebasePreferenceData,
        bytes[] memory _liquidityDistributionData,
        uint8 _mode,
        uint64[] memory _exitStrategy,
        uint64[] memory _rebasePreference,
        uint64[] memory _liquidityDistribution
    )
        public
    {
        (, int24 tick,,,,,) = poolContract.slot0();

        int24 tickLower = floor(tick - 2000, poolContract.tickSpacing());
        int24 tickUpper = floor(tick + 2000, poolContract.tickSpacing());

        strategyKey.pool = poolContract;
        strategyKey.tickLower = tickLower;
        strategyKey.tickUpper = tickUpper;

        actionsData.exitStrategyData = _exitStrategyData;
        actionsData.rebasePreferenceData = _rebasePreferenceData;
        actionsData.liquidityDistributionData = _liquidityDistributionData;

        positionActionsData.mode = _mode;
        positionActionsData.exitStrategy = _exitStrategy;
        positionActionsData.rebasePreference = _rebasePreference;
        positionActionsData.liquidityDistribution = _liquidityDistribution;

        baseContract.createStrategy(strategyKey, actionsData, positionActionsData, false);
    }

    function testCheckStrategies() public {
        bytes32 strategyId = keccak256(abi.encode(address(this), 1));
        bytes32[] memory strategyIds = new bytes32[](1);
        strategyIds[0] = strategyId;

        bytes[] memory rebasePreferenceData = new bytes[](1);
        rebasePreferenceData[0] = abi.encode(1000, 1000, 2000, 2000);

        uint64[] memory rebasePreference = new uint64[](1);
        rebasePreference[0] = 1;

        createBaseContractStrategy(
            new bytes[](0), rebasePreferenceData, new bytes[](0), 2, new uint64[](0), rebasePreference, new uint64[](0)
        );
        bytes32[] memory queue = rebasePreferenceContrat.checkStrategies(strategyIds);
        assertEq(queue[0], strategyId);
    }

    function testExecuteStrategies() public {
        bytes[] memory rebasePreferenceData = new bytes[](1);
        rebasePreferenceData[0] = abi.encode(1000, 1000, 2000, 2000);

        uint64[] memory rebasePreference = new uint64[](1);
        rebasePreference[0] = 1;

        createBaseContractStrategy(
            new bytes[](0), rebasePreferenceData, new bytes[](0), 2, new uint64[](0), rebasePreference, new uint64[](0)
        );

        bytes32 strategyId = keccak256(abi.encode(address(this), 1));
        bytes32[] memory strategyIds = new bytes32[](1);
        strategyIds[0] = strategyId;
        bytes32[] memory queue = rebasePreferenceContrat.checkStrategies(strategyIds);

        rebasePreferenceContrat.toggleOperator(address(this));
        rebasePreferenceContrat.executeStrategies(queue[0]);
    }
}
