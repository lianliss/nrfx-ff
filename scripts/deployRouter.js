const hre = require("hardhat");

async function main() {

  const routerContract = await ethers.getContractFactory("NarfexExchangerRouter2");

  const router = await routerContract.deploy(
  '0xE948F3AE41105118A48B0a656f59C5B4113d404e', // oracle
  '0x38d269BFeECD9871291357F3795E86ae8872A2D8', // pool
  '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d', // usdc
  '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c', // wbnb
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