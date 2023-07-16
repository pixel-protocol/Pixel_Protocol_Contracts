import { ethers } from "hardhat";
import {blockContractAddress,pixelContractAddress, premintColors,premintIds} from "../constants"

async function main() {
  const pixelContractFactory = await ethers.getContractFactory("Pixel");
  const pixelContract = pixelContractFactory.attach(pixelContractAddress);
  const blockContractFactory = await ethers.getContractFactory("Block")
  const blockContract = await blockContractFactory.attach(blockContractAddress)

  for(let index of [10,20,30,40,50,60,70,80,90]) {
    let blockId = premintIds[index]
    let pixelIds = await blockContract.getPixelIds(blockId)
    await pixelContract["transform(uint24[],uint256[])"](premintColors[index],pixelIds)
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
