import { ethers } from "hardhat";

async function main() {
  const pixel = await ethers.getContractFactory("Pixel");

  const Pixel = await pixel.attach("0xb270Dd0cc273014656271E6a6df6cb1C82737bc4")
  for(let i = 0; i <1000; i+=100){
    const row = await Pixel.getCanvasRow(i)
    console.log(row)
  }
  

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
