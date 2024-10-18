const Web3 = require("web3");
const ECR20ABI = require("../out/ERC20/ERC20.sol/ERC20.json");
const CLTABI = require("../out/CLTBase.sol/CLTBase.json");
const CLTModulesABI = require("../out/CLTModules.sol/CLTModules.json");
const CLTTwapABI = require("../out/CLTTwapQuoter.sol/CLTTwapQuoter.json");
const RebaseModuleABI = require("../out/RebaseModule.sol/RebaseModule.json");
const IUniswapV3PoolABI = require("../out/IUniswapV3Pool.sol/IUniswapV3Pool.json");

require("dotenv").config();

const web3 = new Web3("https://virtual.arbitrum.rpc.tenderly.co/0447af23-59dd-463d-9bea-902fcd249ee9");
const contractAddressBase = "0x69317029384c3305fC04670c68a2b434e2D8C44C";
const contractAddressCLTModules = "0x634062496B8ecC63D597401D81d11d5d24eeDD55";
const contractAddressCLTTwapQuoter = "0x6bf322e9db8b725e840dac6fe403b923003584a0";
const contractAddressRebaseModule = "0x7dba7a781b2b4b630257b2afc6c9330dce7dc7ef";
const contractModeModule = "0x599cBbCE726a2d6a849364aB1A5b7ae1573Af0bC";
const MAX_UINT256 = "115792089237316195423570985008687907853269984665640564039457584007913129639935";

const token0 = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F";
const token1 = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6";
const pool = "0xc31e54c7a869b9fcbecc14363cf510d1c41fa443";

const baseContract = new web3.eth.Contract(CLTABI.abi, contractAddressBase);

const ModulesContract = new web3.eth.Contract(CLTModulesABI.abi, contractAddressCLTModules);

const RebaseContract = new web3.eth.Contract(RebaseModuleABI.abi, contractAddressRebaseModule);

const CltTwapContract = new web3.eth.Contract(CLTTwapABI.abi, contractAddressCLTTwapQuoter);

const IUniswapV3PoolContract = new web3.eth.Contract(IUniswapV3PoolABI.abi, pool);

const ercContractToken0 = new web3.eth.Contract(ECR20ABI.abi, token0);
const ercContractToken1 = new web3.eth.Contract(ECR20ABI.abi, token1);

const fromAddress = "0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89";
const fromAddressA89 = "0xa0e9E6B79a3e1AB87FeB209567eF3E0373210a89";
const privateKey = process.env.PRIVATE_KEY_A89;
const privateKeyA89 = process.env.PRIVATE_KEY_A89;

const rebaseStrategy = "0x5eea0aea3d82798e316d046946dbce75c9d5995b956b9e60624a080c7f56f204";
const rebasePricePrefernece = "0xca2ac00817703c8a34fa4f786a4f8f1f1eb57801f5369ebb12f510342c03f53b";
const rebaseInactivity = "0x697d458f1054678eeb971e50a66090683c55cfb1cab904d3050bdfe6ab249893";
const rebaseActiveRebalance = "0x71b5978b6e44da7015285ded9bf0268792b41f7b24b8326894bf7495311010ea";
const modeStrategy = "";

// Define the parameters for createStrategy

const strategyKey = {
  pool: "0x12cdded759b14bf6a34fbf6638aec9b735824a9e",
  tickLower: "-195163",
  tickUpper: "-197163",
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

async function updatePositon() {
  try {
    const balance0 = await ercContractToken0.methods.balanceOf(fromAddressA89).call();
    const balance1 = await ercContractToken1.methods.balanceOf(fromAddressA89).call();

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

async function withdrawPosition() {
  try {
    const positionDetails = await baseContract.methods.positions(1).call();
    const withdrawParams = {
      tokenId: 1,
      liquidity: "10",
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
  console.log(await web3.eth.getBlock(19110525));
}

async function getTwap() {
  console.log();
}

async function getPreferenceTicks(id, actionName, actionData) {
  const twap = await CltTwapContract.methods.getTwap(pool).call();
  const tick = await await CltTwapContract.methods.getCurrentTick(pool).call();;
  console.log("tick", tick.tick);
  console.log("twap", twap);
  const res = await RebaseContract.methods.getPreferenceTicks(id, actionName, actionData).call();
  if (twap > Number(res.upperPreferenceTick) || twap < Number(res.lowerPreferenceTick)) {
    console.log("Eligible For Rebalance");
  } else {
    console.log("Not Eligible For Rebalance");
  }
}


async function rebalanceStrategy(strategyIds) {

  try {
    const rebaseTxn = RebaseContract.methods.executeStrategies(strategyIds);
    const gas = await rebaseTxn.estimateGas({ from: fromAddress });
    const gasPrice = await web3.eth.getGasPrice();

    const txData = {
      to: contractAddressRebaseModule,
      data: rebaseTxn.encodeABI(),
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


const { ethers } = require("ethers");

async function checkBalances(rpcUrl, contractAddress, tokenAddresses) {
  // Create a provider using the RPC URL
  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

  // Check the ETH balance
  try {
    const ethBalance = await provider.getBalance(contractAddress);
    console.log(`ETH Balance: ${ethers.utils.formatEther(ethBalance)} ETH`);
  } catch (error) {
    console.error("Error fetching ETH balance:", error);
  }

  // ABI to interact with ERC-20 token contracts
  const erc20Abi = [
    "function balanceOf(address account) view returns (uint256)",
  ];

  // Iterate over each token address and check the balance
  for (let tokenAddress of tokenAddresses) {
    // Create a contract instance for the token
    const tokenContract = new ethers.Contract(tokenAddress, erc20Abi, provider);

    try {
      // Get the balance of the contract address for the token
      const balance = await tokenContract.balanceOf(contractAddress);

      // Convert balance from wei to a more readable format (e.g., using ethers.utils.formatUnits)
      console.log(`Balance of token ${tokenAddress}: ${ethers.utils.formatUnits(balance, 18)} tokens`);
    } catch (error) {
      console.error(`Error fetching balance for token ${tokenAddress}:`, error);
    }
  }
}
// Example usage
const rpcUrl = "https://virtual.arbitrum.rpc.tenderly.co/1d8acd1c-82cc-4676-aecd-cb09886e848a";
const contractAddress = "0x74226579ed541ada94582dc4cd6ddd21f6526863";
const tokenAddresses = [
  "0xaf88d065e77c8cc2239327c5edb3a432268e5831",
  "0x82af49447d8a07e3bd95bd0d56f35241523fbab1",
  "0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f"
  // Add more token addresses as needed
];

// Run the function
checkBalances(rpcUrl, contractAddress, tokenAddresses);


// async function init(){
//   const strategyId = executeCreateStrategy();
//   approveTokens();
//   deposit(strategyId);
// }

// async function verifyManta() {
//   // Path to your Solidity source code file
//   try {
//     const fetch = (await import("node-fetch")).default;
//     // Update this path to where your Solidity file is actually located
//     const sourceCode = await fs.readFile(
//       "/home/lunar-grave/Documents/Office Work/0.8.15/concentrated-liquidity-tool/src/flatten/RebaseModule.flattened.sol",
//       "utf8",
//     );
//     const response = await fetch(
//       "https://manta-pacific.calderaexplorer.xyz/api/v2/smart-contracts/0x86f5714eCeA724Dc7A7A2bDc005AC36F08a46093/verification/via/flattened-code",
//       {
//         method: "POST",
//         headers: {
//           "Content-Type": "application/json",
//         },
//         body: JSON.stringify({
//           compiler_version: "0.8.15+commit.e14f2714",
//           license_type: "unlicense",
//           source_code: sourceCode,
//           is_optimization_enabled: true,
//           optimization_runs: 4000,
//           contract_name: "RebaseModule",
//           // libraries: {
//           //     LiquidityShares: "0x7794A94FF4C4c6840Cbf92b793092730a068A0e2",
//           //     PoolActions: "0x9D80597D9403bDb35b3d7d9f400377E790b01053",
//           //     Position: "0xC203e40Fb4D742a0559705E33C9C2Af41Af2b4dc",
//           //     StrategyFeeShares: "0xC22E20950aA1f2e91faC75AB7fD8a21eF2C3aB1E",
//           //     TransferHelper: "0x44Ae07568378d2159ED41D0f060a3d6baefBEb97",
//           //     UserPositions: "0x3e0AA2e17FE3E5e319f388C794FdBC3c64Ef9da6",
//           // },
//           evm_version: "london",
//           autodetect_constructor_args: true,
//         }),
//       },
//     );
//     const data = await response.json();
//     console.log(data);
//   } catch (err) {
//     console.error("Failed to submit verification:", err);
//   }
// }

// verifyManta();
// init();
// getBlockDetails();
// txnData();
// executeCreateStrategy();
// addModulesTxn();
// addModulesVaultTxn();
// checkModule();
// checkOwner();
// updatePositon();
// approveTokens();
// deposit("0x353fd513ce55139191f81b229e521f66addb59b7f3501b73a107801c611309e1");
// getStrategyDetails();
// withdrawPosition();
// withdrawPosition();
// getPositionData();
// getTwap();
// getPreferenceTicks("0x73f7e41cf52991a4cd4d6e04eae906fdfeac9b7c76940e77a47924bee10c7651", rebaseActiveRebalance, "0x000000000000000000000000000000000000000000000000000000000000003c0000000000000000000000000000000000000000000000000000000000000064")
// rebalanceStrategy(["0x872c69020c88ca7e7c540c1d53a36f50494f3a41f6a9fc1ca8d83c080b97b6a9"])