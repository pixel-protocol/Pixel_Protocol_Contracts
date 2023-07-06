import { ethers } from "hardhat";
import { blockContractAddress, pixelContractAddress,premintColors,premintIds } from "../constants";

async function main() {
  const blockContractFactory = await ethers.getContractFactory("Block");
  const blockContract = blockContractFactory.attach(blockContractAddress);

  await blockContract.adminMint(premintIds.slice(0, 10),premintColors.slice(0, 10),"0xee709215423b65AD1Ec59e04437635D8c4667A5D")
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
