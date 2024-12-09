// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {LicenseToken} from "../src/LicenseToken.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Validator} from "../src/Validator.sol";

contract ValidatorTest is Test, ERC721Holder {
    event LicenseLocked(address indexed validator, uint256 indexed tokenId, uint256 timestamp);
    event LicenseUnlocked(address indexed validator, uint256 indexed tokenId, uint256 timestamp);
    event RewardClaimed(address indexed validator, uint256 amount);
    event EpochEnded(uint256 epochNumber, uint256 epochReward, uint256 timestamp);

    error NotLicenseOwner();
    error NoRewardToClaim();
    error LicenseAlreadyLocked();
    error LicenseNotLocked();
    error EpochNotEnded();
    error EpochRewardThreshold(uint256 threshold);
    error MaxLicensesExceeded(uint256 maxLicenses);
    error InsufficientRewardBalance(uint256 currentEpochReward, uint256 rewardTokenBalance);
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    Validator public validator;
    RewardToken public rewardToken;
    LicenseToken public licenseToken;

    address public rewardTokenAddress;
    address public licenseTokenAddress;
    uint256 public initialRewards = 1000 ether;

    uint256 public constant BPS = 10000;

    // test accounts
    address internal owner = address(0x01);
    address internal alice = address(0x02);
    address internal bob = address(0x03);

    function setUp() public {
        rewardToken = new RewardToken(initialRewards * 10, owner);
        licenseToken = new LicenseToken();
        rewardTokenAddress = address(rewardToken);
        licenseTokenAddress = address(licenseToken);
        vm.startPrank(owner);
        validator = new Validator(IERC20(rewardTokenAddress), IERC721(licenseTokenAddress), initialRewards);
        rewardToken.transfer(address(validator), rewardToken.balanceOf(owner));
        vm.stopPrank();
    }

    function test_constructor() public {
        assertEq(address(validator.rewardToken()), address(rewardToken));
        assertEq(address(validator.licenseToken()), address(licenseToken));
        assertEq(validator.currentEpochReward(), initialRewards);
        assertEq(validator.totalLockedLicenses(), 0);
        assertEq(validator.currentEpoch(), 0);
        assertEq(validator.lastEpochTimestamp(), block.timestamp);
    }

    function test_lockLicense() public {
        uint256[] memory tokenIds = _mintAndLockLicenses(alice, 2);
        _mintAndLockLicenses(bob, 1);
        (uint256 tokenId1, uint256 tokenId2) = (tokenIds[0], tokenIds[1]);
        (address licenseOwner1, uint256 epoch, uint256 lockTimestamp1) = validator.licensesInfo(tokenId1);
        (address licenseOwner2,, uint256 lockTimestamp2) = validator.licensesInfo(tokenId2);
        assertEq(licenseToken.ownerOf(tokenId1), address(validator));
        assertEq(licenseToken.ownerOf(tokenId2), address(validator));
        assertEq(validator.totalLockedLicenses(), 3);
        assertEq(validator.totalValidators(), 2);
        assertEq(licenseOwner1, alice);
        assertEq(licenseOwner2, alice);
        assertEq(lockTimestamp1, block.timestamp);
        assertEq(lockTimestamp2, block.timestamp);
        assertEq(epoch, validator.currentEpoch());
    }

    function test_lockLicense_expectEmit() public {
        uint256 tokenId = licenseToken.mint(alice);
        vm.startPrank(alice);
        licenseToken.approve(address(validator), tokenId);
        vm.expectEmit(true, true, true, false);
        emit LicenseLocked(alice, tokenId, block.timestamp);
        validator.lockLicense(tokenId);
    }

    function test_lockLicense_RevertWhen_NotOwner() public {
        uint256 tokenId = licenseToken.mint(alice);
        vm.startPrank(alice);
        licenseToken.approve(address(validator), tokenId);
        vm.stopPrank();
        vm.expectPartialRevert(ERC721IncorrectOwner.selector);
        vm.prank(bob);
        validator.lockLicense(tokenId);
    }

    function test_lockLicense_RevertWhen_MaxLicensesExceeded() public {
        _mintAndLockLicenses(alice, 100);
        uint256 tokenId = licenseToken.mint(alice);
        vm.startPrank(alice);
        licenseToken.approve(address(validator), tokenId);
        vm.expectPartialRevert(MaxLicensesExceeded.selector);
        validator.lockLicense(tokenId);
        vm.stopPrank();
    }

    function test_unlockLicense() public {
        uint256[] memory tokenIds = _mintAndLockLicenses(alice, 2);
        vm.warp(block.timestamp + 1 hours);
        _epochEnd();
        vm.startPrank(alice);
        validator.unlockLicense(tokenIds[0]);
        (address licenseOwner, uint256 epoch, uint256 lockTimestamp) = validator.licensesInfo(tokenIds[0]);
        assertEq(licenseToken.ownerOf(tokenIds[0]), alice);
        assertEq(licenseToken.ownerOf(tokenIds[1]), address(validator));
        assertEq(validator.totalLockedLicenses(), 1);
        assertEq(licenseOwner, address(0));
        assertEq(lockTimestamp, 0);
    }

    function test_unlockLicense_ExpectEmit() public {
        uint256 tokenId = _mintAndLockLicense(alice);
        vm.warp(block.timestamp + 1 hours);
        _epochEnd();
        vm.startPrank(alice);
        emit LicenseUnlocked(alice, tokenId, block.timestamp);
        validator.unlockLicense(tokenId);
    }

    function test_unlockLicense_RevertWhen_NotOwner() public {
        uint256 tokenId = licenseToken.mint(alice);
        vm.startPrank(alice);
        licenseToken.approve(address(validator), tokenId);
        validator.lockLicense(tokenId);
        vm.stopPrank();
        vm.expectRevert(NotLicenseOwner.selector);
        validator.unlockLicense(tokenId);
    }

    function test_unlockLicense_RevertWhen_NotLocked() public {
        uint256 tokenId = licenseToken.mint(alice);
        vm.expectRevert(LicenseNotLocked.selector);
        validator.unlockLicense(tokenId);
    }

    function test_unlockLicense_RevertWhen_EpochNotEnded() public {
        uint256 tokenId = _mintAndLockLicense(alice);
        vm.prank(alice);
        vm.expectRevert(EpochNotEnded.selector);
        validator.unlockLicense(tokenId);
    }

    function test_endEpoch() public {
        _mintAndLockLicenses(alice, 2);
        uint256 epochNumber = validator.currentEpoch();
        uint256 epochReward = validator.currentEpochReward();

        vm.warp(block.timestamp + 1 hours);
        _epochEnd();

        assertEq(validator.currentEpoch(), epochNumber + 1);
        assertEq(validator.currentEpochReward(), epochReward * (BPS - validator.REWARD_DECAY()) / BPS);
        assertEq(validator.lastEpochTimestamp(), block.timestamp);

        epochNumber = validator.currentEpoch();
        epochReward = validator.currentEpochReward();
        vm.warp(block.timestamp + 1 hours);
        _epochEnd();
        // epoch reward decays by 10%
        assertEq(validator.currentEpoch(), epochNumber + 1);
        assertEq(validator.currentEpochReward(), epochReward * (BPS - validator.REWARD_DECAY()) / BPS);
        assertEq(validator.lastEpochTimestamp(), block.timestamp);
    }

    function test_endEpoch_ExpectEmit() public {
        _mintAndLockLicenses(alice, 2);
        vm.warp(block.timestamp + 1 hours);
        vm.expectEmit(true, true, true, false);
        emit EpochEnded(validator.currentEpoch(), validator.currentEpochReward(), block.timestamp);
        validator.epochEnd();
    }

    function test_endEpoch_RevertWhen_EpochNotEnded() public {
        vm.expectRevert(EpochNotEnded.selector);
        validator.epochEnd();
    }

    function test_endEpoch_RevertWhen_MeetThreshold() public {
        _mintAndLockLicense(alice);
        uint256 maxEpochs = 66;
        for (uint256 i = 0; i < maxEpochs; i++) {
            vm.warp(block.timestamp + 1 hours);
            _epochEnd();
        }

        vm.warp(block.timestamp + 1 hours);
        vm.expectPartialRevert(EpochRewardThreshold.selector);
        _epochEnd();
    }

    function test_claimReward() public {
        _mintAndLockLicenses(alice, 2);
        _mintAndLockLicense(bob);
        uint256 epochReward = validator.currentEpochReward();
        uint256 aliceWantToClaim = epochReward * 2 / 3;
        uint256 bobWantToClaim = epochReward * 1 / 3;
        vm.warp(block.timestamp + 1 hours);
        _epochEnd();
        uint256 aliceBalanceBefore = rewardToken.balanceOf(alice);
        uint256 bobBalanceBefore = rewardToken.balanceOf(bob);

        vm.prank(alice);
        validator.claimRewards();
        vm.prank(bob);
        validator.claimRewards();

        uint256 aliceBalanceAfter = rewardToken.balanceOf(alice);
        uint256 bobBalanceAfter = rewardToken.balanceOf(bob);

        assertEq(aliceBalanceAfter, aliceBalanceBefore + aliceWantToClaim);
        assertEq(bobBalanceAfter, bobBalanceBefore + bobWantToClaim);
    }

    function test_claimReward_ExpectEmit() public {
        _mintAndLockLicense(alice);
        vm.warp(block.timestamp + 1 hours);
        _epochEnd();
        vm.startPrank(alice);
        vm.expectEmit(true, true, false, false);
        emit RewardClaimed(alice, validator.currentEpochReward());
        validator.claimRewards();
    }

    function test_claimReward_RevertWhen_NoRewards() public {
        _mintAndLockLicense(alice);
        vm.warp(block.timestamp + 1 hours);
        vm.startPrank(alice);
        vm.expectRevert(NoRewardToClaim.selector);
        validator.claimRewards();
    }

    function test_claimReward_RevertWhen_InsufficientBalance() public {
        _mintAndLockLicense(alice);
        vm.warp(block.timestamp + 1 hours);
        _epochEnd();
        uint256 amount = rewardToken.balanceOf(address(validator));
        vm.prank(validator.owner());
        validator.withdrawRewards(amount);
        vm.startPrank(alice);
        vm.expectPartialRevert(InsufficientRewardBalance.selector);
        validator.claimRewards();
    }

    function _mintAndLockLicense(address account) internal returns (uint256) {
        uint256 tokenId = licenseToken.mint(account);
        vm.startPrank(account);
        licenseToken.approve(address(validator), tokenId);
        validator.lockLicense(tokenId);
        vm.stopPrank();
        return tokenId;
    }

    function _mintAndLockLicenses(address account, uint256 count) internal returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _mintAndLockLicense(account);
        }
        return tokenIds;
    }

    function _epochEnd() internal {
        vm.startPrank(owner);
        validator.epochEnd();
        vm.stopPrank();
    }
}
