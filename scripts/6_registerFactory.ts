import { ethers } from "hardhat";
import { stPixelContractAddress, stBlockContractAddress, rentFactoryAddress } from "../constants";

async function main() {
  const stakedBlockContractFactory = await ethers.getContractFactory("StakedBlock");
  const stakedBlockContract = await stakedBlockContractFactory.attach(stBlockContractAddress)
  const stakedPixelContractFactory = await ethers.getContractFactory("StakedPixel");
  const stakedPixelContract = await stakedPixelContractFactory.attach(stPixelContractAddress)

  await stakedBlockContract.registerFactory(rentFactoryAddress)
  await stakedPixelContract.registerFactory(rentFactoryAddress)
  console.log("registered")
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
