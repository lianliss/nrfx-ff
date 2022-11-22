const hre = require("hardhat");

async function main() {

  const balancesContract = await ethers.getContractFactory("BalancesRequest");

  const balances = await balancesContract.deploy();
  await balances.deployed();

  console.log("BalancesRequest deployed to:", balances.address);
}

main() 
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });