const hre = require("hardhat");

async function main() {

  const poolContract = await ethers.getContractFactory("NarfexExchangerPool");

  const pool = await poolContract.deploy(
  '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174', // USDC
  '0xa4FF4DBb11F3186a1e96d3e8DD232E31159Ded9B', // Router
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