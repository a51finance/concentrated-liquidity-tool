import { formatEther } from "ethers/lib/utils";
import { task } from "hardhat/config";
import { Contract, ContractFactory, Signer } from "ethers";

async function deployContract(
  name: string,
  factory: ContractFactory,
  signer: Signer,
  args: Array<any> = [],
): Promise<Contract> {
  const contract = await factory.connect(signer).deploy(...args);
  console.log("Deploying", name);
  console.log("  to", contract.address);
  console.log("  in", contract.deployTransaction.hash);
  return contract.deployed();
}

async function deployBaseContract(
  name: string,
  factory: ContractFactory,
  signer: Signer,
  args: Array<any> = [],
): Promise<Contract> {
  const contract = await factory.connect(signer).deploy(...args);
  console.log("Deploying", name);
  console.log("  to", contract.address);
  console.log("  in", contract.deployTransaction.hash);
  return contract.deployed();
}

// task("deploy-CLTHelper", "Deploy CLTHELPER contract")
//   .addParam("owner", "A51 governance")
//   .addParam("factory", "Factory Address")
//   .addParam("weth", "weth9 Address")
//   .setAction(async (cliArgs, { ethers, run, network }) => {
//     await run("compile");

//     const signer = (await ethers.getSigners())[0];
//     console.log("Signer");
//     console.log("  at", signer.address);
//     console.log("  ETH", formatEther(await signer.getBalance()));
//     console.log("Network");
//     console.log("   ", network.name);

//     console.log("Deploying Libraries");

//     const poolActions = await deployContract("PoolActions", await ethers.getContractFactory("PoolActions"), signer);

//     const liquidityShares = await deployContract(
//       "LiquidityShares",
//       await ethers.getContractFactory("LiquidityShares",{libraries:{PoolActions: poolActions.address}}),
//       signer,
//     );


//     const strategyFeeShares = await deployContract(
//       "StrategyFeeShares",
//       await ethers.getContractFactory("StrategyFeeShares"),
//       signer,
//     );

//     const position = await deployContract("Position", await ethers.getContractFactory("Position"), signer);
   
//     const transferHelper = await deployContract(
//       "TransferHelper",
//       await ethers.getContractFactory("TransferHelper"),
//       signer,
//     );

//     delay(60000);

//     await run("verify:verify", {
//       address: liquidityShares.address,
//       constructorArguments: [],
//     });
//     await run("verify:verify", {
//       address: poolActions.address,
//       constructorArguments: [],
//     });
//     await run("verify:verify", {
//       address: position.address,
//       constructorArguments: [],
//     });
//     await run("verify:verify", {
//       address: strategyFeeShares.address,
//       constructorArguments: [],
//     });
//     await run("verify:verify", {
//       address: transferHelper.address,
//       constructorArguments: [],
//     });

//     const baseContract = await deployBaseContract(
//       "CLTBase",
//       await ethers.getContractFactory("CLTBase", {
//         libraries: {
//           LiquidityShares: liquidityShares.address,
//           PoolActions: poolActions.address,
//           Position: position.address,
//           StrategyFeeShares: strategyFeeShares.address,
//           TransferHelper: transferHelper.address,
//         },
//       }),
//       signer,
//       [
//         "A51 Liquidity Positions NFT",
//         "ALPhy",
//         cliArgs.owner,
//         cliArgs.weth9,
//         0xf4914edb3b7363c73cf9b1884db828e125e1a873,
//         0x1dba4d87b40fdc342cecaea04972a20fb2fc3bc8,
//         cliArgs.factory,
//       ],
//     );

//     await baseContract.deployTransaction.wait(5);

//     delay(60000);

//     await run("verify:verify", {
//       address: baseContract.address,
//       constructorArguments: [
//         "A51 Liquidity Positions NFT",
//         "ALPhy",
//         cliArgs.owner,
//         cliArgs.weth9,
//         0xf4914edb3b7363c73cf9b1884db828e125e1a873,
//         0x1dba4d87b40fdc342cecaea04972a20fb2fc3bc8,
//         cliArgs.factory,
//       ],
//     });
//   });

task("deploy-all", "Deploying all a51 contracts")
  // .addParam("owner", "A51 governance")
  // .addParam("factory", "Factory Address")
  // .addParam("weth", "weth9 Address")
  .setAction(async (cliArgs, { ethers, run, network }) => {
    await run("compile");

    const signer = (await ethers.getSigners())[0];
    console.log("Signer");
    console.log("  at", signer.address);
    console.log("  ETH", formatEther(await signer.getBalance()));
    console.log("Network");
    console.log("   ", network.name);
    console.log("Task Args");

    // const helperContract = await deployContract("CLTHelper", await ethers.getContractFactory("CLTHelper"), signer, []);
    await ethers.getContractFactory("CLTHelper")
    // await helperContract.deployTransaction.wait(5);

    // delay(60000);

    await run("verify:verify", {
      address: "0xA1d8180F4482359CEb7Eb7437FCf4a2616830F81",
      constructorArguments: [],
    });

    // const modulesContract = await deployContract("CLTModules", await ethers.getContractFactory("CLTModules"), signer, [
    //   cliArgs.owner,
    // ]);

    // await modulesContract.deployTransaction.wait(5);

    // delay(60000);

    // await run("verify:verify", {
    //   address: modulesContract.address,
    //   constructorArguments: [cliArgs.owner],
    // });

    // const twapQuoterContract = await deployContract(
    //   "CLTHelper",
    //   await ethers.getContractFactory("CLTTwapQuoter"),
    //   signer,
    //   [cliArgs.owner],
    // );

    // await twapQuoterContract.deployTransaction.wait(5);

    // delay(60000);

    // await run("verify:verify", {
    //   address: twapQuoterContract.address,
    //   constructorArguments: [cliArgs.owner],
    // });

    // const feeParam = {
    //   lpAutomationFee: 0,
    //   strategyCreationFee: 0,
    //   protcolFeeOnManagement: 0,
    //   protcolFeeOnPerformance: 0,
    // };

    // const feeHandlerContract = await deployContract(
    //   "GovernanceFeeHandler",
    //   await ethers.getContractFactory("GovernanceFeeHandler"),
    //   signer,
    //   [cliArgs.owner, feeParam, feeParam],
    // );

    // await feeHandlerContract.deployTransaction.wait(5);

    // delay(60000);

    // await run("verify:verify", {
    //   address: feeHandlerContract.address,
    //   constructorArguments: [cliArgs.owner, feeParam, feeParam],
    // });

    // const baseContract = await deployContract("CLTBase", await ethers.getContractFactory("CLTBase"), signer, [
    //   "A51 Liquidity Positions NFT",
    //   "ALPhy",
    //   cliArgs.owner,
    //   cliArgs.weth9,
    //   feeHandlerContract.address,
    //   modulesContract.address,
    //   cliArgs.factory,
    // ]);

    // await baseContract.deployTransaction.wait(5);

    // delay(60000);

    // await run("verify:verify", {
    //   address: baseContract.address,
    //   constructorArguments: [
    //     "A51 Liquidity Positions NFT",
    //     "ALPhy",
    //     cliArgs.owner,
    //     cliArgs.weth9,
    //     feeHandlerContract.address,
    //     modulesContract.address,
    //     cliArgs.factory,
    //   ],
    // });

    // const modesContract = await deployContract("Modes", await ethers.getContractFactory("Modes"), signer, [
    //   baseContract.address,
    //   twapQuoterContract.address,
    //   cliArgs.owner,
    // ]);

    // await modesContract.deployTransaction.wait(5);

    // delay(60000);

    // await run("verify:verify", {
    //   address: modesContract.address,
    //   constructorArguments: [baseContract.address, twapQuoterContract.address, cliArgs.owner],
    // });

    // const rebaseContract = await deployContract(
    //   "RebaseModule",
    //   await ethers.getContractFactory("RebaseModule"),
    //   signer,
    //   [baseContract.address, twapQuoterContract.address, cliArgs.owner],
    // );

    // await rebaseContract.deployTransaction.wait(5);

    // delay(60000);

    // await run("verify:verify", {
    //   address: rebaseContract.address,
    //   constructorArguments: [baseContract.address, twapQuoterContract.address, cliArgs.owner],
    // });
  });

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
