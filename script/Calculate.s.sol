// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";

contract DecayAmountCalculator {
    uint256 public initialAmount = 1_000 ether;
    uint256 public threshold = 1e9;

    function calculate() public view returns (uint256 iterations, uint256 totalSum) {
        uint256 currentAmount = initialAmount;
        totalSum = 0;
        iterations = 0;

        while (currentAmount >= threshold) {
            totalSum += currentAmount;
            currentAmount = (currentAmount * 9000) / 10000; // 10% decay
            iterations++;
        }
    }
}

contract CalculateScript is Script {
    DecayAmountCalculator public calculator;

    function setUp() public {
        calculator = new DecayAmountCalculator();
    }

    function run() public {
        (uint256 iterations, uint256 totalSum) = calculator.calculate();

        console.log("Epoch count: ", iterations);
        console.log("Total rewards sum: ", totalSum);
    }
}
