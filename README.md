# Raffle Lottery Smart Contract
## Overview
-This project implements a decentralized raffle lottery system using Ethereum smart contracts. Players can enter the raffle by sending a fee, and the system selects a winner based on randomness provided by Chainlink VRF (Verifiable Random Function). It is designed to be modular, with various scripts that handle deployment, testing, and interaction with the contract.

## Technologies Used
-Solidity 0.8.19: Main programming language for Ethereum smart contracts.
-Chainlink VRF: For generating verifiable randomness.
-Foundry: For smart contract testing and deployment.
-Forge: Used for testing with forge-std library.
-Chainlink LinkToken: Mock token for handling randomness and fees.

# MIT License

 # Files
 ## Scripts
## 1. DeployRaffle.sol
-Deploys the Raffle contract along with the required Chainlink VRF coordinator. It includes the configuration for the raffle, such as the entrance fee, interval, and gas limit for callback functions. It also deploys the mock LinkToken to ensure smooth contract interactions during testing.

## 2. Interactions.sol
-This script allows interaction with the deployed raffle contract. It facilitates entering the raffle, checking the contract state, and other useful functions for managing the raffle without needing to directly interact with the blockchain.

## 3. HelperConfig.sol
-Contains helper functions for obtaining the network configurations for different environments (e.g., local or testnets). It provides the contract addresses for Chainlink services, like VRF coordinator, LinkToken, and other configurations like entrance fees and gas lanes.

## Source
## 4. Raffle.sol
-The core raffle contract where players can enter by sending Ether. It tracks participants, processes winner selection via Chainlink VRF, and ensures that the raffle state is managed correctly (open, calculating, closed). Functions for entering, drawing, and checking the state are implemented here.

## Tests
## 5. LinkToken.sol (Mock)
-A mock version of Chainlink’s LinkToken, which is used to simulate transactions involving the VRF service. During tests, this allows the contract to interact with Chainlink VRF as if it were running on a live network.

## 6. RaffleTest.sol
-A comprehensive test suite for the raffle contract. It includes unit tests to ensure the raffle logic functions correctly, such as entering the raffle, validating the entrance fee, emitting events, and performing upkeep. It also tests the randomness of the winner selection and ensures the raffle behaves as expected in different states.

##Inspiration: 
-Inspired by Cyfrin Lottery Smart Contract lessons.

