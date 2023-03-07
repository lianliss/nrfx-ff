const hre = require("hardhat");

async function main() {

  const routerContract = await ethers.getContractFactory("NarfexExchangerRouter2");

  const router = await routerContract.deploy(
  '0xBaBfFCe575929DDd7aD29DEEeb5B7A5F5dee4Ab6', // oracle
  '0xAD1Fc0E22C13159884Cf9FD1d46e3C2Ad60C8F36', // pool
  '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // usdc
  '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // wbnb
  );
  await router.deployed();

  console.log("NarfexExchangerRouter2 deployed to:", router.address);
}

main() 
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });