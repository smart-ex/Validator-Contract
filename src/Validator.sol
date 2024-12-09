// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IValidator} from "./interface/IValidator.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Validator is IValidator, ERC721Holder, Ownable, ReentrancyGuardTransient {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    struct LicenseInfo {
        address owner;
        uint256 epoch;
        uint256 lockTimestamp;
    }

    struct ValidatorInfo {
        uint256 rewards;
        EnumerableSet.UintSet tokenIds;
    }

    IERC20 public immutable rewardToken;
    IERC721 public immutable licenseToken;

    uint256 public constant BPS = 10000;
    uint256 public constant REWARD_DECAY = 1000; // 10%
    uint256 public constant EPOCH_DURATION = 1 hours;
    uint256 public constant EPOCH_REWARD_THRESHOLD = 1 ether;
    uint256 public constant MAX_LICENSES_PER_VALIDATOR = 100; // limit to prevent abuse

    uint256 public totalLockedLicenses;
    uint256 public currentEpoch;
    uint256 public lastEpochTimestamp;
    uint256 public currentEpochReward;

    mapping(uint256 tokenId => LicenseInfo) public licensesInfo;
    mapping(address validator => ValidatorInfo) private validatorInfo;
    EnumerableSet.AddressSet private validatorAddresses;

    constructor(IERC20 _rewardToken, IERC721 _licenseToken, uint256 _initialRewards) Ownable(msg.sender) {
        rewardToken = _rewardToken;
        licenseToken = _licenseToken;
        lastEpochTimestamp = block.timestamp;
        currentEpochReward = _initialRewards;
    }

    function lockLicense(uint256 tokenId) external {
        if (licensesInfo[tokenId].lockTimestamp != 0) {
            revert LicenseAlreadyLocked();
        }
        if (validatorInfo[msg.sender].tokenIds.length() >= MAX_LICENSES_PER_VALIDATOR) {
            revert MaxLicensesExceeded(MAX_LICENSES_PER_VALIDATOR);
        }
        licensesInfo[tokenId] = LicenseInfo({owner: msg.sender, epoch: currentEpoch, lockTimestamp: block.timestamp});

        ValidatorInfo storage validator = validatorInfo[msg.sender];
        validator.tokenIds.add(tokenId);
        validatorAddresses.add(msg.sender);
        totalLockedLicenses++;
        licenseToken.transferFrom(msg.sender, address(this), tokenId);

        emit LicenseLocked(msg.sender, tokenId, block.timestamp);
    }

    function unlockLicense(uint256 tokenId) external {
        if (licensesInfo[tokenId].lockTimestamp == 0) {
            revert LicenseNotLocked();
        }
        if (licensesInfo[tokenId].owner != msg.sender) {
            revert NotLicenseOwner();
        }

        LicenseInfo memory licenseInfo = licensesInfo[tokenId];

        if (licenseInfo.epoch == currentEpoch) {
            revert EpochNotEnded();
        }
        licenseLicenseRemoval(msg.sender, tokenId);
        totalLockedLicenses--;
        licenseToken.transferFrom(address(this), msg.sender, tokenId);

        emit LicenseUnlocked(msg.sender, tokenId, block.timestamp);
    }

    function claimRewards() external nonReentrant {
        uint256 rewards = validatorInfo[msg.sender].rewards;
        if (rewards == 0) {
            revert NoRewardToClaim();
        }
        uint256 rewardTokenBalance = rewardToken.balanceOf(address(this));
        if (rewardTokenBalance < rewards) {
            revert InsufficientRewardBalance(currentEpochReward, rewardTokenBalance);
        }

        validatorInfo[msg.sender].rewards = 0;
        rewardToken.safeTransfer(msg.sender, rewards);

        emit RewardClaimed(msg.sender, rewards);
    }

    function epochEnd() external {
        if (lastEpochTimestamp + EPOCH_DURATION > block.timestamp) {
            revert EpochNotEnded();
        }
        if (currentEpochReward <= EPOCH_REWARD_THRESHOLD) {
            revert EpochRewardThreshold(EPOCH_REWARD_THRESHOLD);
        }

        uint256 previousEpoch = currentEpoch;
        uint256 previousEpochReward = currentEpochReward;
        // Distribute rewards proportionally
        if (totalLockedLicenses > 0) {
            uint256 rewardPerLicense = previousEpochReward / totalLockedLicenses;
            distributeRewards(rewardPerLicense);
        }

        // Decay reward for next epoch
        currentEpochReward = currentEpochReward * (BPS - REWARD_DECAY) / BPS;

        currentEpoch++;
        lastEpochTimestamp = block.timestamp;

        emit EpochEnded(previousEpoch, previousEpochReward, block.timestamp);
    }

    function getValidatorInfo(address validator) external view returns (uint256 rewards, uint256[] memory tokenIds) {
        ValidatorInfo storage info = validatorInfo[validator];
        tokenIds = info.tokenIds.values();
        rewards = info.rewards;
    }

    function getValidatorAddresses() external view returns (address[] memory) {
        return validatorAddresses.values();
    }

    function totalValidators() external view returns (uint256) {
        return validatorAddresses.length();
    }

    function withdrawRewards(uint256 amount) external onlyOwner {
        require(rewardToken.balanceOf(address(this)) >= amount, "Insufficient reward balance");
        rewardToken.safeTransfer(owner(), amount);
    }

    function distributeRewards(uint256 rewardPerLicense) internal {
        address[] memory addresses = validatorAddresses.values();

        for (uint256 i = 0; i < addresses.length; i++) {
            address validator = addresses[i];
            uint256 validatorLicenseCount = validatorInfo[validator].tokenIds.length();

            if (validatorLicenseCount > 0) {
                uint256 validatorReward = validatorLicenseCount * rewardPerLicense;
                validatorInfo[validator].rewards += validatorReward;
            }
        }
    }

    function licenseLicenseRemoval(address validator, uint256 tokenId) internal {
        EnumerableSet.UintSet storage tokenIds = validatorInfo[validator].tokenIds;
        require(tokenIds.remove(tokenId));
        delete licensesInfo[tokenId];
        if (tokenIds.length() == 0) {
            require(validatorAddresses.remove(validator));
        }
    }
}
