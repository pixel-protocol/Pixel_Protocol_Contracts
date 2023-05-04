import { expect, assert } from "chai";
import { ethers } from "hardhat";
import { mine, time } from "@nomicfoundation/hardhat-network-helpers";

describe("Pixel", function () {
  before("deploy contract", async function () {

    const [owner, addr1, addr2] = await ethers.getSigners()
    const Pixel = await ethers.getContractFactory("Pixel");
    const pixel = await Pixel.deploy();
    await pixel.deployed();



    expect(await pixel.owner()).to.equal(owner.address);
  });

  // showcase test on how to use the Hardhat network helpers library
  it("Should mine the given number of blocks", async function () {
    const blockNumberBefore = await time.latestBlock();

    await mine(100);

    assert.equal(await time.latestBlock(), blockNumberBefore + 100);
  });
});
