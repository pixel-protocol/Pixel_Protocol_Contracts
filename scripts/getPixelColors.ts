import { ethers } from "hardhat";

async function main() {
  const blockContractFactory = await ethers.getContractFactory("Block");
  const blockContract = blockContractFactory.attach("0x1699151c66f1818f5b712de0F0770370E9F58eE1");

  
  const colors = await blockContract.getPixelColors(1);
  console.log(colors);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
