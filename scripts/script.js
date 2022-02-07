
const hre = require("hardhat");

async function main() {
  const Funnel = await hre.ethers.getContractFactory("Funnel");
  const funnel = await Funnel.deploy();

  await funnel.deployed();

  // Workaround for bug where deployed address on Mumbai network is incorrect
  const txHash = funnel.deployTransaction.hash;
  console.log(`Tx hash: ${txHash}\nWaiting for transaction to be mined...`);
  const txReceipt = await hre.ethers.provider.waitForTransaction(txHash);

  console.log("Funnel contract address:", txReceipt.contractAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
