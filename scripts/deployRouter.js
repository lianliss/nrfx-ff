const hre = require("hardhat");

async function main() {

  const routerContract = await ethers.getContractFactory("NarfexExchangerRouter");

  const router = await routerContract.deploy(
  '0xF9ceb479201054d2B301f9052A5fFBe47D652358',
  '0x3764Be118a1e09257851A3BD636D48DFeab5CAFE',
  '0x1c1dc05d3f7df354a1b6a1d1b5ef1870beb3f91d'
  );
  await router.deployed();

  console.log("NarfexExchangerRouter deployed to:", router.address);
}

main() 
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });