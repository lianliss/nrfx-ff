const hre = require("hardhat");

async function main() {

  const poolContract = await ethers.getContractFactory("NarfexExchangerPool");

  const pool = await poolContract.deploy(
  '0x55d398326f99059fF775485246999027B3197955',
  '0xa4FF4DBb11F3186a1e96d3e8DD232E31159Ded9B',
  );
  await pool.deployed();

  console.log("NarfexExchangerPool deployed to:", pool.address);
}

main() 
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });