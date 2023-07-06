import { ethers } from "hardhat";

async function main() {
  const rentUpkeepManagerContractFactory = await ethers.getContractFactory(
    "RentUpkeepManager"
  );
  const rentUpkeepManagerContract =
    await rentUpkeepManagerContractFactory.deploy();

  await rentUpkeepManagerContract.deployed();
  console.log(
    "RentUpkeepManager deployed to:",
    rentUpkeepManagerContract.address
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
