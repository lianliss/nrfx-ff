const hre = require("hardhat");

async function main() {

  const routerContract = await ethers.getContractFactory("NarfexExchangerRouter2");

  const router = await routerContract.deploy(
  '0xC8f30866816fdab9Bb6BDbbb03d4a54103145c99', // oracle
  '0x60c68cb00C77AA0f46Af9eaB32695E4eFBEbd45C', // pool
  '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174', // usdc
  '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270', // wbnb
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