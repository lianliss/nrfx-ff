const hre = require("hardhat");

async function main() {

  const pool = await (await ethers.getContractFactory("NarfexExchangerPool")).deploy(
    '0xd92271C20A5a3A03d8Eb6244D1c002EBed525605',
    '0xa4FF4DBb11F3186a1e96d3e8DD232E31159Ded9B',
    '0xcDA8eD22bB27Fe84615f368D09B5A8Afe4a99320',
    '0x30ca20913C00a8E6D785340769ee17a7c5045109',
  );
  await pool.deployed();
  console.log("NarfexExchangerPool deployed to:", pool.address);
  
  const router = await (await ethers.getContractFactory("NarfexP2pRouter")).deploy(
    '0x5bA23078FaB7Dd3A6d7b5049a2C711Ef8ba7E8d0',
    pool.address,
    '0xd92271C20A5a3A03d8Eb6244D1c002EBed525605',
    '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd',
  );
  await router.deployed();
  console.log("NarfexP2pRouter deployed to:", router.address);
  
  const kyc = await (await ethers.getContractFactory("NarfexKYC")).deploy();
  await kyc.deployed();
  console.log("NarfexKYC deployed to:", kyc.address);
  
  const lawyers = await (await ethers.getContractFactory("NarfexLawyers")).deploy();
  await lawyers.deployed();
  console.log("NarfexLawyers deployed to:", lawyers.address);
  
  const buyFactory = await (await ethers.getContractFactory("NarfexP2pBuyFactory")).deploy(
    '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd',
    kyc.address,
    lawyers.address,
    router.address,
  );
  await buyFactory.deployed();
  console.log("NarfexP2pBuyFactory deployed to:", buyFactory.address);
  
  const sellFactory = await (await ethers.getContractFactory("NarfexP2pSellFactory")).deploy(
    '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd',
    kyc.address,
    lawyers.address,
    router.address,
  );
  await sellFactory.deployed();
  console.log("NarfexP2pSellFactory deployed to:", sellFactory.address);
}

main() 
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });