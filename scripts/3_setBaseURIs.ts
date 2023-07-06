import { ethers } from "hardhat";
import { blockContractAddress, pixelContractAddress } from "../constants";

async function main() {
  const pixelContractFactory = await ethers.getContractFactory("Pixel");
  const pixelContract = pixelContractFactory.attach(pixelContractAddress);
  const blockContractFactory = await ethers.getContractFactory("Block");
  const blockContract = blockContractFactory.attach(blockContractAddress);


  await pixelContract.setBaseURI("https://www.pixelprotocol.net/api/pixels/");
  console.log("Pixel base URI set");

  await blockContract.setBaseURI("https://www.pixelprotocol.net/api/blocks/");
  console.log("Block base URI set");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
