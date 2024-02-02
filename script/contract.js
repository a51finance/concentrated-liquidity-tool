const Web3 = require("web3");
const ECR20ABI = require("../out/ERC20/ERC20.sol/ERC20.json");
const CLTABI = require("../out/CLTBase.sol/CLTBase.json");
const CLTModulesABI = require("../out/CLTModules.sol/CLTModules.json");
const RebaseModuleABI = require("../out/RebaseModule.sol/RebaseModule.json");

require("dotenv").config();

const web3 = new Web3("https://virtual.mainnet.rpc.tenderly.co/d1adf8c2-1e1c-4193-9a78-dc9df644db3e");
const contractAddressBase = "0x23733faF3aed2c71F2430D638069BD17381294dF";
const contractAddressCLTModules = "0xf506458ebdeb67d946cb8817005457db0d993212";
const contractAddressRebaseModule = "0xe5b89c31a367afcda71e233b1371e54d5b78d24e";
const MAX_UINT256 = "115792089237316195423570985008687907853269984665640564039457584007913129639935";

const token0 = "0x6b175474e89094c44da98b954eedeac495271d0f";
const token1 = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

const contractABIBase = CLTABI.abi;
const baseContract = new web3.eth.Contract(contractABIBase, contractAddressBase);

const contractABIModules = CLTModulesABI.abi;
const ModulesContract = new web3.eth.Contract(contractABIModules, contractAddressCLTModules);

const contractABIRebase = RebaseModuleABI.abi;
const RebaseContract = new web3.eth.Contract(contractABIRebase, contractAddressRebaseModule);

const ERC20ABI = ECR20ABI.abi;
const ercContractToken0 = new web3.eth.Contract(ERC20ABI, token0);
const ercContractToken1 = new web3.eth.Contract(ERC20ABI, token1);

const fromAddress = "0x97fF40b5678D2234B1E5C894b5F39b8BA8535431";
const fromAddressA89 = "0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89";
const privateKey = process.env.PRIVATE_KEY;
const privateKeyA89 = process.env.PRIVATE_KEY_A89;

const rebaseStrategy = "0x5eea0aea3d82798e316d046946dbce75c9d5995b956b9e60624a080c7f56f204";
const rebasePricePrefernece = "0xca2ac00817703c8a34fa4f786a4f8f1f1eb57801f5369ebb12f510342c03f53b";
const rebaseInactivity = "0x697d458f1054678eeb971e50a66090683c55cfb1cab904d3050bdfe6ab249893";

// Define the parameters for createStrategy


// const strategyKey = {
//   pool: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
//   tickLower: "197050",
//   tickUpper: "201050",
// };

const strategyKey = {
  pool: "0x5777d92f208679db4b9778590fa3cab3ac9e2168",
  tickLower: "-278954",
  tickUpper: "-272802",
};

const positionActions = {
  exitStrategy: [],
  liquidityDistribution: [],
  mode: "2",
  rebaseStrategy: [
    {
      actionName: "0xca2ac00817703c8a34fa4f786a4f8f1f1eb57801f5369ebb12f510342c03f53b",
      data: "0x00000000000000000000000000000000000000000000000000000000000003040000000000000000000000000000000000000000000000000000000000000d44",
    },
  ],
};
const managementFees = "100000000000000000";
const performanceFees = "50000000000000000";
const isCompound = true;
const isPrivate = false;

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

    const depoitAmount0 = "5000";
    const depoitAmount1 = "500";

    const depositTx = baseContract.methods.deposit({
      strategyId: strategyId,
      amount0Desired: depoitAmount0,
      amount1Desired: depoitAmount1,
      amount0Min: depoitAmount0,
      amount1Min: depoitAmount1,
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

    const depoitAmount0 = "500000000";
    const depoitAmount1 = "500000000000000000000";
    const tokenId = 1;

    const depositTx = baseContract.methods.updatePositionLiquidity({
      tokenId,
      amount0Desired: depoitAmount0,
      amount1Desired: depoitAmount1,
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
      liquidity: "100",
      recipient: fromAddress,
      refundAsETH: false,
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
    const addModuleTxn = ModulesContract.methods.setNewModule(rebaseStrategy, rebaseInactivity);
    // const addModuleTxn = ModulesContract.methods.setNewModule(rebaseStrategy, rebasePricePrefernece);
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
    const addModuleTxn = ModulesContract.methods.setModuleAddress(rebaseStrategy, contractAddressRebaseModule);
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
  console.log(await web3.eth.getBlock(19110525))
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
// deposit("0x353fd513ce55139191f81b229e521f66addb59b7f3501b73a107801c611309e1");
// updatePositon();
// approveTokens();
// getStrategyDetails();
withdrawPosition();
// getPositionData();
