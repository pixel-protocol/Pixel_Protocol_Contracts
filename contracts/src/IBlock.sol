// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBlock {
    event Mint(address indexed caller, uint256 blockId, uint256[] pixelIds, uint24[] pixelColors);
    function mint(uint256 id_, uint24[] memory colors_) external payable;
    function getPixelIds(uint256 id_) external view returns(uint256[] memory);
    function getPixelOwners(uint256 id_) external view returns(address[] memory);
    function getPixelColors(uint256 id_) external view returns(uint24[] memory);
}