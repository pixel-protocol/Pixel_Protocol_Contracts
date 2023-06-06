import { ethers } from "hardhat";
import {blockContractAddress,pixelContractAddress} from "../constants"

async function main() {
  const pixelContractFactory = await ethers.getContractFactory("Pixel");
  const pixelContract = pixelContractFactory.attach(pixelContractAddress);

  await pixelContract["transferFrom(address,address,uint256[])"]("0xee709215423b65ad1ec59e04437635d8c4667a5d", "0x65d6396599e1CE1A744C4e633C4e6e51bfab59af",[11,12,1010,1011,1012,2011,2012,2013,2014,2015,3012,3014,3016,4010,4011,4012,4013,4014,4015])
  console.log("Transferred");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
