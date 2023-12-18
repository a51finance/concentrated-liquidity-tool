const Web3 = require("web3");
const ECR20ABI = require("../out/ERC20/ERC20.sol/ERC20.json");
const CLTABI = require("../out/CLTBase.sol/CLTBase.json");
const CLTModulesABI = require("../out/CLTModules.sol/CLTModules.json");
const RebaseModuleABI = require("../out/RebaseModule.sol/RebaseModule.json");

require("dotenv").config();

const web3 = new Web3("https://eth-goerli.g.alchemy.com/v2/oD-Ft2zD3u6MzlCs5b7x-LzTK0OAL5--");
const contractAddressBase = "0xfe7c0f4318cCEC6e664bF984F1AD04e7d0665c97";
const contractAddressCLTModules = "0xAe8Da829c739da2d83166d6f7932641F417596ce";
const contractAddressRebaseModule = "0x6409c7638E761F85d77456f7659C5C01e35880e1";
const MAX_UINT256 = "115792089237316195423570985008687907853269984665640564039457584007913129639935";
const token0 = "0x3c5d67de8e81d65caa5552f5260d6986d4ea9f88";
const token1 = "0xc71d5bc18438903dc9fff9b88088ac2d2bbea2e1";

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
const strategyKey = {
  pool: "0xb810a57202388b59102feBf04dEfd0051Fe0344A",
  tickLower: "140",
  tickUpper: "340",
};
const positionActions = {
  exitStrategy: [],
  liquidityDistribution: [],
  mode: "2",
  rebaseStrategy: [
    {
      actionName: "0xca2ac00817703c8a34fa4f786a4f8f1f1eb57801f5369ebb12f510342c03f53b",
      data: "0x00000000000000000000000000000000000000000000000000000000000000c80000000000000000000000000000000000000000000000000000000000000086",
    },
  ],
};
const managementFees = 0;
const performanceFees = 0;
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
  } catch (error) {
    console.error("Error executing createStrategy:", error);
  }
}

async function approveTokens() {
  const txn0 = ercContractToken0.methods.approve(contractAddressBase, MAX_UINT256);
  const txn1 = ercContractToken1.methods.approve(contractAddressBase, MAX_UINT256);

  const gas0 = await txn0.estimateGas({ from: fromAddressA89 });
  const gas1 = await txn1.estimateGas({ from: fromAddressA89 });
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

  const signedTx0 = await web3.eth.accounts.signTransaction(txData0, privateKeyA89);
  const receipt0 = await web3.eth.sendSignedTransaction(signedTx0.rawTransaction);
  console.log("Transaction successful:", receipt0);

  const signedTx1 = await web3.eth.accounts.signTransaction(txData1, privateKeyA89);
  const receipt1 = await web3.eth.sendSignedTransaction(signedTx1.rawTransaction);
  console.log("Transaction successful receipt0:", receipt0);
  console.log("Transaction successful receipt1:", receipt1);
}

async function deposit() {
  try {
    const depoitAmount0 = "1000000000";
    const depoitAmount1 = "1000000000";

    const depositTx = baseContract.methods.deposit(
      "0x353fd513ce55139191f81b229e521f66addb59b7f3501b73a107801c611309e1",
      depoitAmount0,
      depoitAmount1,
      depoitAmount0,
      depoitAmount1,
      fromAddressA89,
    );

    const gas = await depositTx.estimateGas({ from: fromAddressA89 });
    const gasPrice = await web3.eth.getGasPrice();

    const txData = {
      to: contractAddressBase,
      data: depositTx.encodeABI(),
      gas,
      gasPrice,
    };

    const signedTx = await web3.eth.accounts.signTransaction(txData, privateKeyA89);
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

// txnData();
executeCreateStrategy();
// addModulesTxn();
// addModulesVaultTxn();
// checkModule();
// checkOwner();
// deposit();
// approveTokens();
