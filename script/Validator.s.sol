// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Validator} from "../src/Validator.sol";

contract ValidatorScript is Script {
    Validator public validator;
    // should be set before run
    address public rewardTokenAddress;
    address public licenseTokenAddress;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        validator = new Validator(IERC20(rewardTokenAddress), IERC721(licenseTokenAddress), 1000 ether);

        vm.stopBroadcast();
    }
}
