import { ethers } from "hardhat";
import { blockContractAddress, premintIds,premintColors } from "../constants";


async function main() {
  const blockContractFactory = await ethers.getContractFactory("Block");
  const blockContract = blockContractFactory.attach(blockContractAddress);

for(let i=91;i<100;i++){
await blockContract.mint(premintIds[i],premintColors[i],{ value: ethers.utils.parseEther("0.2") })
}
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
