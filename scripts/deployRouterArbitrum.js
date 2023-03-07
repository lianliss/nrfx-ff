const hre = require("hardhat");

async function main() {

  const routerContract = await ethers.getContractFactory("NarfexExchangerRouter2");

  const router = await routerContract.deploy(
  '0xcDA8eD22bB27Fe84615f368D09B5A8Afe4a99320', // oracle
  '0x4CC22BA6A0fFaA248B6a704330d26Be84DcC1405', // pool
  '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8', // usdc
  '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', // wbnb
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