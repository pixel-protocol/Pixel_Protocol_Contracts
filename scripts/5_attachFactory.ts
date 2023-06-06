import { ethers } from "hardhat";
import { rentFactoryAddress, rentUpkeepManagerAddress } from "../constants";

async function main() {

  const rentUpkeepManagerContractFactory = await ethers.getContractFactory("RentUpkeepManager");
  const rentUpkeepManagerContract = rentUpkeepManagerContractFactory.attach(rentUpkeepManagerAddress);


  await rentUpkeepManagerContract.attachFactory(rentFactoryAddress);
  console.log("Factory attached!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
