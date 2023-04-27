const hre = require("hardhat");

async function main() {
  
  const narfexContract = await ethers.getContractFactory("NarfexToken");

  const narfex = await narfexContract.deploy(
    "0x01b443495834D667b42f54d2b77eEd6951eD94a4",
    "0xCc17e34794B6c160a0F61B58CF30AA6a2a268625",
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