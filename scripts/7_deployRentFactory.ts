import { ethers } from "hardhat";

async function main() {
  const rentFactoryContractFactory = await ethers.getContractFactory(
    "RentFactory"
  );
  const rentFactoryContract = await rentFactoryContractFactory.deploy();

  await rentFactoryContract.deployed();
  console.log("RentFactory deployed to:", rentFactoryContract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
