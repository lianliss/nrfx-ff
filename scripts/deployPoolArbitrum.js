const hre = require("hardhat");

async function main() {

  const poolContract = await ethers.getContractFactory("NarfexExchangerPool");

  const pool = await poolContract.deploy(
  '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8', // USDC
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