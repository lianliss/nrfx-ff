const hre = require("hardhat");

async function main() {

  const poolContract = await ethers.getContractFactory("NarfexExchangerPool");

  const pool = await poolContract.deploy(
  '0x7ef95a0FEE0Dd31b22626fA2e10Ee6A223F8a684',
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