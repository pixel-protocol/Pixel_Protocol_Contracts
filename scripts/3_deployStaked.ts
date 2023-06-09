import { ethers } from "hardhat";

async function main() {
  const stakedPixelContractFactory = await ethers.getContractFactory("StakedPixel");
  const stakedPixelContract = await stakedPixelContractFactory.deploy();

  await stakedPixelContract.deployed();
  console.log("stPixel deployed to:", stakedPixelContract.address);

  const stakedBlockContractFactory = await ethers.getContractFactory("StakedBlock");
  const stakedBlockContract = await stakedBlockContractFactory.deploy();

  await stakedBlockContract.deployed();
  console.log("stBlock deployed to:", stakedBlockContract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
