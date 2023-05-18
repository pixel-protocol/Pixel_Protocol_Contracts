// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPixel {
    event ColorChange(address indexed caller, uint256[] ids, uint24[] colors);
    function mint(uint24[] memory colors_, uint256[] memory ids_, address buyer_) external;
    function transform(uint24 color_, uint256 id_) external;
    function transform(uint24[] memory colors_, uint256[] memory ids_) external;
    function getCanvasRow(uint256 row_) external view returns (uint24[] memory);
    function pixelOwner(uint256 id_) external view returns(address);
}