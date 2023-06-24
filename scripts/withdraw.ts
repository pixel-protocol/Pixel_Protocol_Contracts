import { ethers } from "hardhat";

async function main() {
  const blockContractFactory = await ethers.getContractFactory("Block");
  const blockContract = blockContractFactory.attach("0xbDb7c44fE4fcfC380EecB40ae237360285B55D2d");

  
  await blockContract.withdraw();
  console.log("Withdrawn!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
