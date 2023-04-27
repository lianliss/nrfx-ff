const hre = require("hardhat");

async function main() {

  const poolContract = await ethers.getContractFactory("NarfexExchangerPool");

  const pool = await poolContract.deploy(
  '0x4CC22BA6A0fFaA248B6a704330d26Be84DcC1405', // USDC
  '0xa4FF4DBb11F3186a1e96d3e8DD232E31159Ded9B', // Router
  '0xa4FF4DBb11F3186a1e96d3e8DD232E31159Ded9B', // NRFX
  '0xa4FF4DBb11F3186a1e96d3e8DD232E31159Ded9B', // MasterChef
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