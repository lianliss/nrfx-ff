const hre = require("hardhat");

async function main() {

  const routerContract = await ethers.getContractFactory("NarfexExchangerRouter2");

  const router = await routerContract.deploy(
  '0x0CdCad1e2c9C59920E916aDC75B7b21B5c2f78D5', // oracle
  '0xFd9947Ad969ac228eb7792535c4F015CCdfED739', // pool
  '0x7ef95a0FEE0Dd31b22626fA2e10Ee6A223F8a684', // usdt
  '0xae13d989dac2f0debff460ac112a837c89baa7cd', // wbnb
  '0xF1f8206c94F38525E94919E7381889B3d6D57Ac5', // fiat factory
  '0xcDA8eD22bB27Fe84615f368D09B5A8Afe4a99320', // nrfx
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