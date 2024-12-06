// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IValidator {
    // Locks a license (ERC721 token) in the contract and registers the validator for rewards. Emits an event.
    function lockLicense(uint256 tokenId) external;
    // Allows unlocking the license only if one full epoch has passed since it was locked. Returns the license to the owner.
    function unlockLicense(uint256 tokenId) external;
    // Transfers accumulated ERC20 rewards to the validator. Rewards are proportional to the number of locked licenses and epochs elapsed.
    function claimRewards() external;
    // Ends the current epoch, distributes rewards among validators, and decreases the reward pool for the next epoch.
    function epochEnd() external;
}
