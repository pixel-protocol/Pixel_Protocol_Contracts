import { ethers } from "hardhat";
import {blockTempContractAddress,pixelTempContractAddress} from "../../constants"

async function main() {
  const blockContractFactory = await ethers.getContractFactory("BlockTemp");
  const blockContract = blockContractFactory.attach(blockTempContractAddress);

  
  await blockContract.withdraw();
  console.log("Withdrawn!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
