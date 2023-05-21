const hre = require("hardhat");

async function main() {

  
  const buy = await (await ethers.getContractFactory("NarfexP2pBuyOffer")).deploy(
    '0x7c7Bd759b684c3dA55804f6200959fd6393F4Eea',
    '0xa4FF4DBb11F3186a1e96d3e8DD232E31159Ded9B',
    '0x93e9fefdb37431882D1A27bB794E73a191ebD945',
    100,
    0,
    0,
  );
  await buy.deployed();
  console.log("NarfexP2pBuyOffer deployed to:", buy.address);
  
  
  const sell = await (await ethers.getContractFactory("NarfexP2pSellOffer")).deploy(
    '0x95fc1A5cFCb83a39108b81c32791cC8C5Ce0062e',
    '0xa4FF4DBb11F3186a1e96d3e8DD232E31159Ded9B',
    '0x93e9fefdb37431882D1A27bB794E73a191ebD945',
    '0x7177650000000000000000000000000000000000000000000000000000000000',
    100,
    0,
    0,
  );
  await sell.deployed();
  console.log("NarfexP2pSellOffer deployed to:", sell.address);
  
}

main() 
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });