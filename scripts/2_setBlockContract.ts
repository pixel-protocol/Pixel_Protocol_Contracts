import { ethers } from "hardhat";
import {blockContractAddress,pixelContractAddress} from "../constants"

async function main() {
  const pixelContractFactory = await ethers.getContractFactory("Pixel");
  const pixelContract = pixelContractFactory.attach(pixelContractAddress);

  await pixelContract.setBlockContract(blockContractAddress);
  console.log("Block contract set");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
