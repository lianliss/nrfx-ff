const hre = require("hardhat");

async function main() {

  const usdcContract = await ethers.getContractFactory("TestnetUSDC");

  const usdc = await usdcContract.deploy();
  await usdc.deployed();

  console.log("TestnetUSDC deployed to:", usdc.address);
}

main() 
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });