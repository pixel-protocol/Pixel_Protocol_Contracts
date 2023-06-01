import { ethers } from "hardhat";
import {blockTempContractAddress,pixelTempContractAddress} from "../../constants"

async function main() {
  const pixelContractFactory = await ethers.getContractFactory("PixelTemp");
  const pixelContract = pixelContractFactory.attach(pixelTempContractAddress);

  const pixelExists = await pixelContract.exists(0);
  console.log(pixelExists);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
