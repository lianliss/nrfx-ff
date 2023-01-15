const hre = require("hardhat");

async function main() {

  const routerContract = await ethers.getContractFactory("NarfexExchangerRouter2");

  const router = await routerContract.deploy(
  '0xE948F3AE41105118A48B0a656f59C5B4113d404e', // oracle
  '0x40fA05f47C0aC1033Fa94e4d6aD398B4BB4d1007', // pool
  '0x55d398326f99059fF775485246999027B3197955', // usdt
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