const hre = require("hardhat");

async function main() {

  const routerContract = await ethers.getContractFactory("NarfexExchangerRouter2");

  const router = await routerContract.deploy(
  '0x5bA23078FaB7Dd3A6d7b5049a2C711Ef8ba7E8d0', // oracle
  '0x3cF75915dc42fb4c9baA3aF7608719Bd7f1b58a5', // pool
  '0xd92271C20A5a3A03d8Eb6244D1c002EBed525605', // usdc
  '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd', // wbnb
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