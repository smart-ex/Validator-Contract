// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {LicenseToken} from "../src/LicenseToken.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Validator} from "../src/Validator.sol";

contract ValidatorTest is Test, ERC721Holder {
    Validator public validator;
    RewardToken public rewardToken;
    LicenseToken public licenseToken;
    address public rewardTokenAddress;
    address public licenseTokenAddress;

    function setUp() public {
        rewardToken = new RewardToken(10000 ether);
        licenseToken = new LicenseToken();
        rewardTokenAddress = address(rewardToken);
        licenseTokenAddress = address(licenseToken);
        console.log("rewardTokenAddress: ", rewardTokenAddress);
        console.log("licenseTokenAddress: ", licenseTokenAddress);

        validator = new Validator(IERC20(rewardTokenAddress), IERC721(licenseTokenAddress));
    }

    function test_constructor() public {
        assertEq(address(validator.rewardToken()), address(rewardToken));
        assertEq(address(validator.licenseToken()), address(licenseToken));
    }

    function test_lockLicense() public {
        licenseToken.mint(address(this), 1);
        licenseToken.approve(address(validator), 1);
        validator.lockLicense(1);
        assertEq(licenseToken.ownerOf(1), address(validator));
    }

    function test_unlockLicense() public {
        licenseToken.mint(address(this), 1);
        licenseToken.approve(address(validator), 1);
        validator.lockLicense(1);
        validator.unlockLicense(1);
        assertEq(licenseToken.ownerOf(1), address(this));
    }
}
