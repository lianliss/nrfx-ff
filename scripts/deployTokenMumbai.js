const hre = require("hardhat");

async function main() {
  
  const narfexContract = await ethers.getContractFactory("NarfexToken");

  const narfex = await narfexContract.deploy(
    "0x0000000000000000000000000000000000000000",
    "0xa4FF4DBb11F3186a1e96d3e8DD232E31159Ded9B",
  );
  await narfex.deployed();
  
  console.log("NarfexToken deployed to:", narfex.address);
}

main() 
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });