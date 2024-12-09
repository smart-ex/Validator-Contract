// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LicenseToken is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    constructor() ERC721("LicenseToken", "LT") Ownable(msg.sender) {}

    function mint(address to) public onlyOwner returns (uint256) {
        _tokenIdCounter++;
        _safeMint(to, _tokenIdCounter);
        return _tokenIdCounter;
    }

    function burn(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }
}
