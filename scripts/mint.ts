import { ethers } from "hardhat";
import { blockContractAddress, pixelContractAddress,premintColors,premintIds } from "../constants";

async function main() {
  const blockContractFactory = await ethers.getContractFactory("Block");
  const blockContract = blockContractFactory.attach(blockContractAddress);
  const color = premintColors[0]
  console.log(color.length)
  await blockContract["mint(uint256,uint24[])"](0,color)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
