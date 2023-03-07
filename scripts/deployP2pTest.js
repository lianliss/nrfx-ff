const hre = require("hardhat");

async function main() {

  /**
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
  **/
  
  const factory = await (await ethers.getContractFactory("NarfexP2pFactory")).deploy(
    '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd',
    '0xA097dB585AEEaEd3B5F2909503597cb8c6c05145',
    '0x6b16719Ba47f902955278c8eF16ed97AA15234F1',
    '0x7B8d000649eaE22b8e45c28295Cc41111d5c8f60',
  );
  await factory.deployed();
  console.log("NarfexP2pFactory deployed to:", factory.address);
}

main() 
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });