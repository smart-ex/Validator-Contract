// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IValidator} from "./interface/IValidator.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Validator is IValidator, ERC721Holder, Ownable {
    IERC20 public rewardToken;
    IERC721 public licenseToken;
    uint256 public epochDuration;
    uint256 public epochStart;
    uint256 public totalRewards;

    //    function startEpoch(uint256 _epochDuration, uint256 _totalRewards) external {
    //        epochDuration = _epochDuration;
    //        epochStart = block.timestamp;
    //        totalRewards = _totalRewards;
    //    }

    constructor(IERC20 _rewardToken, IERC721 _licenseToken) Ownable(msg.sender) {
        rewardToken = _rewardToken;
        licenseToken = _licenseToken;
    }

    function lockLicense(uint256 tokenId) external override {
        licenseToken.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    function unlockLicense(uint256 tokenId) external override {
        licenseToken.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function claimRewards() external override {
        rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
    }

    function epochEnd() external override {
        // implement the function
    }
}
