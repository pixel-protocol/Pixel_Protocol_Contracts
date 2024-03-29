import { ethers } from "hardhat";
import { blockContractAddress } from "../constants";

async function main() {
  const blockContractFactory = await ethers.getContractFactory("Block");
  const blockContract = blockContractFactory.attach(blockContractAddress);

  
  await blockContract.withdraw();
  console.log("Withdrawn!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
