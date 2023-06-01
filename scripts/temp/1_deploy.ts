import { ethers } from "hardhat";

async function main() {
  const pixelContractFactory = await ethers.getContractFactory("PixelTemp");
  const pixelContract = await pixelContractFactory.deploy();

  await pixelContract.deployed();
  console.log("Pixel deployed to:", pixelContract.address);

  const blockContractFactory = await ethers.getContractFactory("BlockTemp");
  const blockContract = await blockContractFactory.deploy(pixelContract.address);

  await blockContract.deployed();
  console.log("Block deployed to:", blockContract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
