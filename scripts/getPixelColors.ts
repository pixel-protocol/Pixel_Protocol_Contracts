import { ethers } from "hardhat";
import { blockContractAddress } from "../constants";

async function main() {
  const blockContractFactory = await ethers.getContractFactory("Block");
  const blockContract = blockContractFactory.attach(blockContractAddress);

  
  const colors = await blockContract.getPixelColors(0);
  console.log(colors);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
