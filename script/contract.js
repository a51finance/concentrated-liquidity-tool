const Web3 = require("web3");
const ECR20ABI = require("../out/ERC20.sol/ERC20.json");
const CLTABI = require("../out/CLTBase.sol/CLTBase.json");
const CLTModulesABI = require("../out/CLTModules.sol/CLTModules.json");

const RebaseModuleABI = require("../out/RebaseModule.sol/RebaseModule.json");

require("dotenv").config();

const web3 = new Web3("https://rpc.linea.build");
const contractAddressBase = "0xA8Dc31c8C9F93dB2e42A5472F580689794639576";
const contractAddressCLTModules = "0xAE668406d5f08e3E916C1D6A1a3F3F64c803DC4E";
const contractAddressRebaseModule = "0x525C80e91efE9222DE3EAe86AF69A480fbced416";
const contractAddressMode = "0x4cc3305ee36ea4b8763AAd4465A016Aed944342E";
const contractAddressTwapQuoter = "0xb0ca4Bbb5c66276BEA8B3349234dDeAB1FBda050";
const contractAddressFeeHandler = "0xCF47Aa71aD8f734ce727f0D4eA357AF7eb014F43";
const MAX_UINT256 = "115792089237316195423570985008687907853269984665640564039457584007913129639935";

const token0 = "0x176211869cA2b568f2A7D4EE941E073a821EE1ff";
const token1 = "0xA219439258ca9da29E9Cc4cE5596924745e12B93";

const contractABIBase = CLTABI.abi;
const baseContract = new web3.eth.Contract(contractABIBase, contractAddressBase);

const contractABIModules = CLTModulesABI.abi;
const ModulesContract = new web3.eth.Contract(contractABIModules, contractAddressCLTModules);

const contractABIRebase = RebaseModuleABI.abi;
const RebaseContract = new web3.eth.Contract(contractABIRebase, contractAddressRebaseModule);

const ERC20ABI = ECR20ABI.abi;
const ercContractToken0 = new web3.eth.Contract(ERC20ABI, token0);
const ercContractToken1 = new web3.eth.Contract(ERC20ABI, token1);

const fromAddress = "0x9a9DdE861b91B965DEAA0ce2D208DBE693e87fCb";
const privateKey = process.env.PRIVATE_KEY_MAIN;

const rebaseStrategy = "0x5eea0aea3d82798e316d046946dbce75c9d5995b956b9e60624a080c7f56f204";
const rebasePricePrefernece = "0xca2ac00817703c8a34fa4f786a4f8f1f1eb57801f5369ebb12f510342c03f53b";
const rebaseInactivity = "0x697d458f1054678eeb971e50a66090683c55cfb1cab904d3050bdfe6ab249893";
const mode = "0x25d202ee31c346b8c1099dc1a469d77ca5ac14ed43336c881902290b83e0a13a";
// Define the parameters for createStrategy

const strategyKey = {
  pool: "0x6e9ad0b8a41e2c148e7b0385d3ecbfdb8a216a9b",
  tickLower: "-3",
  tickUpper: "3",
};

const positionActions = {
  exitStrategy: [],
  liquidityDistribution: [],
  mode: "3",
  rebaseStrategy: [
    {
      actionName: "0xca2ac00817703c8a34fa4f786a4f8f1f1eb57801f5369ebb12f510342c03f53b",
      data: "0x00000000000000000000000000000000000000000000000000000000000003040000000000000000000000000000000000000000000000000000000000000d44",
    },
  ],
};
const managementFees = "0";
const performanceFees = "0";
const isCompound = true;
const isPrivate = false;

async function changeOwner() {
  console.log("Tansferring ownership on twap quoter...");
}

async function executeCreateStrategy() {
  try {
    const createStrategyTx = baseContract.methods.createStrategy(
      strategyKey,
      positionActions,
      managementFees,
      performanceFees,
      isCompound,
      isPrivate,
    );
    const gas = await createStrategyTx.estimateGas({ from: fromAddress });
    const gasPrice = await web3.eth.getGasPrice();

    const txData = {
      to: contractAddressBase,
      data: createStrategyTx.encodeABI(),
      gas,
      gasPrice,
    };

    const signedTx = await web3.eth.accounts.signTransaction(txData, privateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);

    console.log("Transaction successful:", receipt);
    console.log("Strategy ID:", receipt.logs[0].topics[1]);
    return receipt.logs[0].topics[1].toString();
  } catch (error) {
    console.error("Error executing createStrategy:", error);
  }
}

async function approveTokens() {
  const txn0 = ercContractToken0.methods.approve(contractAddressBase, MAX_UINT256);
  const txn1 = ercContractToken1.methods.approve(contractAddressBase, MAX_UINT256);

  const gas0 = await txn0.estimateGas({ from: fromAddress });
  const gas1 = await txn1.estimateGas({ from: fromAddress });
  const gasPrice = await web3.eth.getGasPrice();

  const txData0 = {
    to: token0,
    data: txn0.encodeABI(),
    gas: gas0,
    gasPrice,
  };

  const txData1 = {
    to: token1,
    data: txn1.encodeABI(),
    gas: gas1,
    gasPrice,
  };

  const signedTx0 = await web3.eth.accounts.signTransaction(txData0, privateKey);
  const receipt0 = await web3.eth.sendSignedTransaction(signedTx0.rawTransaction);
  console.log("Transaction successful:", receipt0);

  const signedTx1 = await web3.eth.accounts.signTransaction(txData1, privateKey);
  const receipt1 = await web3.eth.sendSignedTransaction(signedTx1.rawTransaction);
  console.log("Transaction successful receipt0:", receipt0);
  console.log("Transaction successful receipt1:", receipt1);
}

async function deposit(strategyId) {
  try {
    const balance0 = await ercContractToken0.methods.balanceOf(fromAddress).call();
    const balance1 = await ercContractToken1.methods.balanceOf(fromAddress).call();

    if (balance0 == 0 || balance1 == 0) {
      throw "Insufficient funds";
    }
    const depoitAmount0 = balance0;
    const depoitAmount1 = balance1;

    const depositTx = baseContract.methods.deposit({
      strategyId: strategyId,
      amount0Desired: depoitAmount0 - 2,
      amount1Desired: depoitAmount1 - 2,
      amount0Min: 0,
      amount1Min: 0,
      recipient: fromAddress,
    });

    const gas = await depositTx.estimateGas({ from: fromAddress });
    const gasPrice = await web3.eth.getGasPrice();

    const txData = {
      to: contractAddressBase,
      data: depositTx.encodeABI(),
      gas,
      gasPrice,
    };

    const signedTx = await web3.eth.accounts.signTransaction(txData, privateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
    console.log("Transaction successful:", receipt);
  } catch (error) {
    console.log(error);
  }
}

async function updatePositon() {
  try {
    const balance0 = await ercContractToken0.methods.balanceOf(fromAddress).call();
    const balance1 = await ercContractToken1.methods.balanceOf(fromAddress).call();

    if (balance0 == 0 || balance1 == 0) {
      throw "Insufficient funds";
    }

    const depoitAmount0 = balance0;
    const depoitAmount1 = balance1;
    const tokenId = 1;

    const depositTx = baseContract.methods.updatePositionLiquidity({
      tokenId,
      amount0Desired: depoitAmount0,
      amount1Desired: depoitAmount1,
      amount0Min: 0,
      amount1Min: 0,
    });

    const gas = await depositTx.estimateGas({ from: fromAddress });
    const gasPrice = await web3.eth.getGasPrice();

    const txData = {
      to: contractAddressBase,
      data: depositTx.encodeABI(),
      gas,
      gasPrice,
    };

    const signedTx = await web3.eth.accounts.signTransaction(txData, privateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
    console.log("Transaction successful:", receipt);
  } catch (error) {
    console.log(error);
  }
}

async function withdrawPosition() {
  try {
    const positionDetails = await baseContract.methods.positions(1).call();
    const withdrawParams = {
      tokenId: 1,
      liquidity: "1000",
      recipient: fromAddress,
      refundAsETH: false,
      amount0Min: 0,
      amount1Min: 0,
    };

    const depositTx = baseContract.methods.withdraw(withdrawParams);

    const gas = await depositTx.estimateGas({ from: fromAddress });
    const gasPrice = await web3.eth.getGasPrice();

    const txData = {
      to: contractAddressBase,
      data: depositTx.encodeABI(),
      gas,
      gasPrice,
    };

    const signedTx = await web3.eth.accounts.signTransaction(txData, privateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
    console.log("Transaction successful:", receipt);
  } catch (error) {
    console.log(error);
  }
}

async function addModulesTxn() {
  try {
    // const addModuleTxn = ModulesContract.methods.setNewModule(rebaseStrategy, rebaseInactivity);
    const addModuleTxn = ModulesContract.methods.setNewModule(rebaseStrategy, rebasePricePrefernece);
    const gas = await addModuleTxn.estimateGas({ from: fromAddress });
    const gasPrice = await web3.eth.getGasPrice();

    const txData = {
      to: contractAddressCLTModules,
      data: addModuleTxn.encodeABI(),
      gas,
      gasPrice,
    };

    const signedTx = await web3.eth.accounts.signTransaction(txData, privateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
    console.log("Transaction successful:", receipt);
  } catch (error) {
    console.error("Error executing createStrategy:", error);
  }
}

async function addModulesVaultTxn() {
  try {
    // const addModuleTxn = ModulesContract.methods.setModuleAddress(rebaseStrategy, contractAddressRebaseModule);
    const addModuleTxn = ModulesContract.methods.setModuleAddress(mode, contractAddressMode);
    const gas = await addModuleTxn.estimateGas({ from: fromAddress });
    const gasPrice = await web3.eth.getGasPrice();
    const txData = {
      to: contractAddressCLTModules,
      data: addModuleTxn.encodeABI(),
      gas,
      gasPrice,
    };

    const signedTx = await web3.eth.accounts.signTransaction(txData, privateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);

    console.log("Transaction successful:", receipt);
  } catch (error) {
    console.error("Error executing createStrategy:", error);
  }
}

async function checkModule() {
  console.log(await ModulesContract.methods.modeVaults(rebaseStrategy).call());
}

async function checkOwner() {
  console.log(await baseContract.methods.name().call());
}

async function txnData() {
  // baseContract.once("StrategyCreated",{})
  const block = await web3.eth.getTransactionReceipt(
    "0x8440cb943400e908cb2cc0aa8d05d47e22dc496eb4799098b5ee547af070812d",
  );

  console.log(block.logs[0].topics[1]);
}

async function getStrategyDetails() {
  const strategyId = "0x353fd513ce55139191f81b229e521f66addb59b7f3501b73a107801c611309e1";
  const details = await baseContract.methods.strategies(strategyId).call();
  console.log(details);
}

async function getPositionData() {
  const position = 1;
  const positionDetails = await baseContract.methods.positions(1).call();
  console.log(positionDetails);
}

async function getBlockDetails() {
  console.log(await web3.eth.getBlock(19110518));
  console.log(await web3.eth.getBlock(19110525));
}

// async function init(){
//   const strategyId = executeCreateStrategy();
//   approveTokens();
//   deposit(strategyId);
// }

// init();
// getBlockDetails();
// txnData();
// executeCreateStrategy();
// addModulesTxn();
// addModulesVaultTxn();
// checkModule();
// checkOwner();
updatePositon();
// approveTokens();
// deposit("0xdbcd6241a0bc20ac9bba364cff84a4e6755d2f97d24dd8c8eb977d185d4013cc");
// getStrategyDetails();
// withdrawPosition();
// withdrawPosition();
// getPositionData();
