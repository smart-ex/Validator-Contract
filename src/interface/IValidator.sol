// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IValidator {

    event LicenseLocked(address indexed validator, uint256 indexed tokenId, uint256 timestamp);
    event LicenseUnlocked(address indexed validator, uint256 indexed tokenId, uint256 timestamp);
    event RewardClaimed(address indexed validator, uint256 amount);
    event EpochEnded(uint256 epochNumber, uint256 epochReward, uint256 timestamp);

    error NotLicenseOwner();
    error LicenseNotLocked();
    error NoRewardToClaim();
    error LicenseAlreadyLocked();
    error EpochNotEnded();
    error EpochRewardThreshold(uint256 threshold);
    error MaxLicensesExceeded(uint256 maxLicenses);
    error InsufficientRewardBalance(uint256 currentEpochReward, uint256 rewardTokenBalance);

    // Locks a license (ERC721 token) in the contract and registers the validator for rewards.
    // Emits an event.
    function lockLicense(uint256 tokenId) external;
    // Allows unlocking the license only if one full epoch has passed since it was locked.
    // Returns the license to the owner.
    function unlockLicense(uint256 tokenId) external;
    // Transfers accumulated ERC20 rewards to the validator. Rewards are proportional to the number of locked licenses and epochs elapsed.
    function claimRewards() external;
    // Ends the current epoch, distributes rewards among validators, and decreases the reward pool for the next epoch.
    function epochEnd() external;
}
