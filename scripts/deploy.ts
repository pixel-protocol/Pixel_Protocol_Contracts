import { ethers } from "hardhat";

async function main() {
  const contract = await ethers.deployContract("Pixel");

  await contract.deployed();
  console.log("cPixelNFT deployed to:", contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
