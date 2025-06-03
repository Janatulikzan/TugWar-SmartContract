// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {TugWarContract} from "../src/TugWarContract.sol";

contract DeployTugWar is Script {
    TugWarContract public tugWarContract;

    function setUp() public {}

    function run() public returns (TugWarContract, address) {
        console.log("Starting TugWar Game deployment to Monad Testnet...");
        console.log("");

        // Get deployer account from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployment Details:");
        console.log("Deployer address:", deployer);
        
        // Check balance
        uint256 balance = deployer.balance;
        console.log("Deployer balance:", balance / 1e18, "MON");
        
        if (balance < 0.01 ether) {
            console.log("Warning: Low balance. Make sure you have enough MON for deployment.");
        }

        // Get network info
        console.log("Network: Monad Testnet");
        console.log("Chain ID: 10143");
        console.log("RPC URL: https://testnet-rpc.monad.xyz/");
        console.log("");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying TugWar contract...");
        
        // Deploy TugWar with deployer as owner
        tugWarContract = new TugWarContract(deployer);
        address contractAddress = address(tugWarContract);

        vm.stopBroadcast();

        console.log("TugWar deployed successfully!");
        console.log("Contract address:", contractAddress);
        console.log("Block explorer:", string.concat("https://testnet.monadexplorer.com/address/", _addressToString(contractAddress)));

        // Verify initial state
        console.log("");
        console.log("Verifying initial contract state...");
        address owner = tugWarContract.owner();
        int8 ropePosition = tugWarContract.ropePosition();
        uint8 team1Score = tugWarContract.team1Score();
        uint8 team2Score = tugWarContract.team2Score();
        uint8 maxScoreDifference = tugWarContract.maxScoreDifference();
        uint256 totalPulls = tugWarContract.totalPulls();
        uint256 gamesPlayed = tugWarContract.gamesPlayed();

        console.log("Owner:", owner);
        console.log("Rope position:", vm.toString(ropePosition));
        console.log("Team 1 score:", team1Score);
        console.log("Team 2 score:", team2Score);
        console.log("Max score difference:", maxScoreDifference);
        console.log("Total pulls:", totalPulls);
        console.log("Games played:", gamesPlayed);
        
        // Test view functions
        console.log("");
        console.log("Testing contract functions...");
        uint8 winStatus = tugWarContract.getWinStatus();
        bool canStart = tugWarContract.canStartGame();
        
        console.log("Win status (0=ongoing):", winStatus);
        console.log("Can start game:", canStart);

        // Provide game instructions
        console.log("");
        console.log("Game Instructions:");
        console.log("Two teams compete in a tug of war");
        console.log("Each pull moves the rope position");
        console.log("Team 1 pulls decrease rope position (negative)");
        console.log("Team 2 pulls increase rope position (positive)");
        console.log("First team to reach score difference of", maxScoreDifference, "wins");
        console.log("Owner can reset game and change rules");

        // Provide next steps
        console.log("");
        console.log("Next Steps:");
        console.log("1. Save the contract address for future interactions");
        console.log("2. Verify the contract on block explorer (optional)");
        console.log("3. Test game functions using cast or frontend");
        console.log("4. Add players and start your first game!");
        console.log("5. Monitor game events and statistics");

        return (tugWarContract, contractAddress);
    }

    function _addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
}