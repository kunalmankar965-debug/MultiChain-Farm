const { ethers } = require("hardhat");

async function main() {
  const MultiChainFarm = await ethers.getContractFactory("MultiChainFarm");
  const multiChainFarm = await MultiChainFarm.deploy();

  await multiChainFarm.deployed();

  console.log("MultiChainFarm contract deployed to:", multiChainFarm.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
