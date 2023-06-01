import { ethers } from "hardhat";
import {blockTempContractAddress,pixelTempContractAddress} from "../../constants"

async function main() {
  const pixelContractFactory = await ethers.getContractFactory("PixelTemp");
  const pixelContract = pixelContractFactory.attach(pixelTempContractAddress);

  await pixelContract.setBlockContract(blockTempContractAddress);
  console.log("Block contract set");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
