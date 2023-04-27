const hre = require("hardhat");

async function main() {

  const routerContract = await ethers.getContractFactory("NarfexExchangerRouter2");

  const router = await routerContract.deploy(
  '0xe56f902B21d540FC031531C1Da4b50f4377aFE81', // oracle
  '0x60c68cb00C77AA0f46Af9eaB32695E4eFBEbd45C', // pool
  '0x4CC22BA6A0fFaA248B6a704330d26Be84DcC1405', // usdc
  '0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889', // wbnb
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