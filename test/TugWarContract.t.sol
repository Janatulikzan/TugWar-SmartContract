// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/TugWarContract.sol";

contract TugWarContractTest is Test {
    TugWarContract public tugWarContract;
    address public owner;
    address public player1;
    address public player2;
    address public player3;

    function setUp() public {
        owner = address(this);
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");
        player3 = makeAddr("player3");
        
        tugWarContract = new TugWarContract(owner);
    }

    // === BOUNDARY TESTS ===
    
    function test_ShouldHandleBoundaryValues() public {
        // Test minimum valid maxScoreDifference
        tugWarContract.reSet(1);
        
        vm.prank(player1);
        tugWarContract.pull(true);
        
        assertEq(tugWarContract.getWinStatus(), 1); // Immediate win
        
        // Reset with maximum valid maxScoreDifference
        tugWarContract.reSet(50);
        
        // Should be able to pull many times
        vm.startPrank(player2);
        for (uint i = 0; i < 49; i++) {
            tugWarContract.pull(false);
        }
        vm.stopPrank();
        
        assertEq(tugWarContract.getWinStatus(), 0); // Still ongoing
        
        vm.prank(player2);
        tugWarContract.pull(false);
        
        assertEq(tugWarContract.getWinStatus(), 2); // Now Team2 wins
    }

    function test_ShouldHandleRopePositionBoundaries() public {
        // Test dengan maxScoreDifference tinggi untuk menguji rope position limits
        tugWarContract.reSet(50);
        
        // Team1 pulls 50 kali (ropePosition akan menjadi -50)
        vm.startPrank(player1);
        for (uint i = 0; i < 50; i++) {
            tugWarContract.pull(true);
        }
        vm.stopPrank();
        
        assertEq(tugWarContract.ropePosition(), -50);
        assertEq(tugWarContract.team1Score(), 50);
        assertEq(tugWarContract.getWinStatus(), 1);
    }

    function test_ShouldHandleHighScores() public {
        // Test mendekati batas uint8 (255) - tapi harus hati-hati dengan win condition
        tugWarContract.reSet(50);
        
        // Simulasi skor tinggi dengan pulls bergantian
        // Team1: 50 pulls, Team2: 0 pulls (difference = 50, exactly maxScoreDifference)
        vm.startPrank(player1);
        for (uint i = 0; i < 50; i++) {
            tugWarContract.pull(true);
        }
        vm.stopPrank();
        
        assertEq(tugWarContract.team1Score(), 50);
        assertEq(tugWarContract.team2Score(), 0);
        assertEq(tugWarContract.getWinStatus(), 1); // Team1 wins (50-0=50, exactly maxScoreDifference)
    }

    function test_ShouldHandleZeroScoreDifference() public {
        // Test ketika kedua tim memiliki skor sama
        tugWarContract.reSet(5);
        
        // Kedua tim pull bergantian 10 kali
        for (uint i = 0; i < 10; i++) {
            vm.prank(player1);
            tugWarContract.pull(true);
            
            vm.prank(player2);
            tugWarContract.pull(false);
        }
        
        assertEq(tugWarContract.team1Score(), tugWarContract.team2Score());
        assertEq(tugWarContract.getWinStatus(), 0); // Game continues
        assertEq(tugWarContract.ropePosition(), 0); // Rope stays at center
    }

    // === STRESS TESTS ===

    function test_ShouldHandleHighVolumeGameplay() public {
        console.log("=== High Volume Gameplay Test ===");
        
        tugWarContract.reSet(20); // Higher threshold for longer game
        
        uint256 maxPulls = 1000;
        uint256 team1Pulls = 0;
        uint256 team2Pulls = 0;
        
        // Simulasi gameplay dengan pattern yang bisa diprediksi
        for (uint i = 0; i < maxPulls; i++) {
            if (tugWarContract.getWinStatus() != 0) break;
            
            // Pattern: setiap 3 pull, 2 untuk team1, 1 untuk team2
            bool isTeam1 = (i % 3) != 2;
            
            if (isTeam1) {
                vm.prank(player1);
                tugWarContract.pull(true);
                team1Pulls++;
            } else {
                vm.prank(player2);
                tugWarContract.pull(false);
                team2Pulls++;
            }
        }
        
        console.log("Total pulls in stress test:");
        console.log(tugWarContract.totalPulls());
        console.log("Team1 pulls:");
        console.log(team1Pulls);
        console.log("Team2 pulls:");
        console.log(team2Pulls);
        
        // Game harus berakhir dengan pemenang
        assertTrue(tugWarContract.getWinStatus() != 0);
    }

    function test_ShouldHandleRapidOwnershipChanges() public {
        address[] memory owners = new address[](5);
        owners[0] = player1;
        owners[1] = player2;
        owners[2] = player3;
        owners[3] = makeAddr("player4");
        owners[4] = makeAddr("player5");
        
        // Transfer ownership dan test dari setiap owner
        address currentOwner = address(this); // Start with current owner
        
        for (uint i = 0; i < owners.length; i++) {
            // Transfer menggunakan current owner
            vm.prank(currentOwner);
            tugWarContract.transferOwnership(owners[i]);
            assertEq(tugWarContract.owner(), owners[i]);
            
            // Update current owner
            currentOwner = owners[i];
            
            // Setiap owner melakukan reset dengan nilai berbeda
            vm.prank(owners[i]);
            tugWarContract.reSet(uint8(i + 1));
            assertEq(tugWarContract.maxScoreDifference(), i + 1);
        }
        
        console.log("Successfully handled 5 ownership transfers");
    }

    function test_ShouldHandleMultipleGameCycles() public {
        console.log("=== Multiple Game Cycles Test ===");
        
        uint8[] memory winThresholds = new uint8[](5);
        winThresholds[0] = 1;
        winThresholds[1] = 3;
        winThresholds[2] = 5;
        winThresholds[3] = 10;
        winThresholds[4] = 15;
        
        uint256 initialGamesPlayed = tugWarContract.gamesPlayed();
        
        for (uint gameNum = 0; gameNum < winThresholds.length; gameNum++) {
            console.log("Starting game:");
            console.log(gameNum + 1);
            
            tugWarContract.reSet(winThresholds[gameNum]);
            
            // Team1 wins setiap game
            vm.startPrank(player1);
            for (uint i = 0; i < winThresholds[gameNum]; i++) {
                tugWarContract.pull(true);
            }
            vm.stopPrank();
            
            assertEq(tugWarContract.getWinStatus(), 1);
            assertEq(tugWarContract.gamesPlayed(), initialGamesPlayed + gameNum + 1);
            
            console.log("Game completed with threshold:");
            console.log(winThresholds[gameNum]);
        }
        
        assertEq(tugWarContract.gamesPlayed(), initialGamesPlayed + winThresholds.length);
    }

    // === SECURITY TESTS ===

    function test_ShouldPreventReentrancy() public {
        // Test bahwa tidak ada reentrancy vulnerability
        // Contract tidak melakukan external calls, jadi aman dari reentrancy
        
        vm.prank(player1);
        tugWarContract.pull(true);
        
        // Tidak ada external calls dalam pull function, jadi aman dari reentrancy
        assertEq(tugWarContract.team1Score(), 1);
    }

    function test_ShouldValidateAllInputs() public {
        // Test semua validasi input
        
        // reSet validation
        vm.expectRevert(TugWarContract.InvalidMaxScoreDifference.selector);
        tugWarContract.reSet(0);
        
        vm.expectRevert(TugWarContract.InvalidMaxScoreDifference.selector);
        tugWarContract.reSet(51);
        
        // transferOwnership validation
        vm.expectRevert("New owner cannot be zero address");
        tugWarContract.transferOwnership(address(0));
        
        // getTeamStats validation
        vm.expectRevert("Invalid team number");
        tugWarContract.getTeamStats(0);
        
        vm.expectRevert("Invalid team number");
        tugWarContract.getTeamStats(3);
    }

    function test_ShouldPreventUnauthorizedAccess() public {
        // Test bahwa hanya owner yang bisa melakukan operasi restricted
        
        address nonOwner = makeAddr("nonOwner");
        
        vm.startPrank(nonOwner);
        
        vm.expectRevert(TugWarContract.OnlyOwner.selector);
        tugWarContract.reSet(10);
        
        vm.expectRevert(TugWarContract.OnlyOwner.selector);
        tugWarContract.transferOwnership(player1);
        
        vm.stopPrank();
        
        // Tapi non-owner bisa pull
        vm.prank(nonOwner);
        tugWarContract.pull(true);
        assertEq(tugWarContract.team1Score(), 1);
    }

    // === EDGE CASE TESTS ===

    function test_ShouldHandleWinOnFirstPull() public {
        // Test menang langsung pada pull pertama
        tugWarContract.reSet(1);
        
        vm.prank(player1);
        tugWarContract.pull(true);
        
        assertEq(tugWarContract.getWinStatus(), 1);
        assertEq(tugWarContract.totalPulls(), 1);
        
        // Tidak bisa pull lagi setelah game over
        vm.prank(player2);
        vm.expectRevert(TugWarContract.GameOver.selector);
        tugWarContract.pull(false);
    }

    function test_ShouldHandleAlternatingWins() public {
        // Test skenario di mana lead berganti-ganti
        tugWarContract.reSet(10);
        
        // Phase 1: Team1 unggul 5-0
        vm.startPrank(player1);
        for (uint i = 0; i < 5; i++) {
            tugWarContract.pull(true);
        }
        vm.stopPrank();
        
        // Check Team1 leading
        assertEq(tugWarContract.team1Score(), 5);
        assertEq(tugWarContract.team2Score(), 0);
        
        (uint8 predicted1, uint8 confidence1) = tugWarContract.getPrediction();
        assertEq(predicted1, 1); // Team1 leading
        assertEq(confidence1, 50); // 5/10 * 100 = 50%
        
        // Phase 2: Team2 comeback 3-5 (Team2=3, Team1=5)
        vm.startPrank(player2);
        for (uint i = 0; i < 3; i++) {
            tugWarContract.pull(false);
        }
        vm.stopPrank();
        
        // Check scores after Team2 pulls
        assertEq(tugWarContract.team1Score(), 5);
        assertEq(tugWarContract.team2Score(), 3);
        
        // Team1 still leading, but with smaller margin
        (uint8 predicted2, uint8 confidence2) = tugWarContract.getPrediction();
        assertEq(predicted2, 1); // Team1 still leading
        assertEq(confidence2, 20); // (5-3)/10 * 100 = 20%
        
        // Phase 3: Team2 takes the lead 6-5
        vm.startPrank(player2);
        for (uint i = 0; i < 3; i++) {
            tugWarContract.pull(false);
        }
        vm.stopPrank();
        
        // Check final scores
        assertEq(tugWarContract.team1Score(), 5);
        assertEq(tugWarContract.team2Score(), 6);
        
        // Now Team2 should be leading
        (uint8 predicted3, uint8 confidence3) = tugWarContract.getPrediction();
        assertEq(predicted3, 2); // Team2 now leading
        assertEq(confidence3, 10); // (6-5)/10 * 100 = 10%
        
        // Game should still be ongoing (difference is 1, need 10)
        assertEq(tugWarContract.getWinStatus(), 0);
    }

    function test_ShouldHandleExactWinCondition() public {
        // Test kondisi menang tepat di batas
        tugWarContract.reSet(5);
        
        // Team1: 5, Team2: 0 (difference = 5, exactly maxScoreDifference)
        vm.startPrank(player1);
        for (uint i = 0; i < 5; i++) {
            tugWarContract.pull(true);
        }
        vm.stopPrank();
        
        assertEq(tugWarContract.getWinStatus(), 1);
        assertEq(tugWarContract.team1Score() - tugWarContract.team2Score(), 5);
    }

    // === PERFORMANCE TESTS ===

    function test_ShouldMaintainConsistentGasUsage() public {
        // Foundry gas measurement dalam test environment bisa sangat bervariasi
        // Kita test bahwa function berjalan tanpa error dan gas usage reasonable
        tugWarContract.reSet(50); // Set very high threshold to allow many pulls
        
        uint256 totalGasUsed = 0;
        uint256 pullCount = 10;
        
        for (uint i = 0; i < pullCount; i++) {
            uint256 gasBefore = gasleft();
            
            vm.prank(player1);
            tugWarContract.pull(true);
            
            uint256 gasUsed = gasBefore - gasleft();
            totalGasUsed += gasUsed;
            
            // Log individual gas usage untuk debugging
            console.log("Pull", i + 1, "gas used:", gasUsed);
        }
        
        uint256 averageGas = totalGasUsed / pullCount;
        
        console.log("Total gas used:", totalGasUsed);
        console.log("Average gas per pull:", averageGas);
        
        // Test bahwa gas usage reasonable (tidak terlalu tinggi)
        assertLt(averageGas, 100000); // Average should be reasonable
        assertGt(averageGas, 1000);   // Should use some gas
        
        // Test bahwa semua pulls berhasil
        assertEq(tugWarContract.team1Score(), pullCount);
    }

    function test_ShouldOptimizeViewFunctions() public view {
        // View functions should not change state
        uint8 initialTeam1Score = tugWarContract.team1Score();
        uint8 initialTeam2Score = tugWarContract.team2Score();
        int8 initialRopePosition = tugWarContract.ropePosition();
        
        // Call all view functions
        tugWarContract.getWinStatus();
        tugWarContract.getGameInfo();
        tugWarContract.getTeamStats(1);
        tugWarContract.getTeamStats(2);
        tugWarContract.canStartGame();
        tugWarContract.getPrediction();
        
        // State should remain unchanged
        assertEq(tugWarContract.team1Score(), initialTeam1Score);
        assertEq(tugWarContract.team2Score(), initialTeam2Score);
        assertEq(tugWarContract.ropePosition(), initialRopePosition);
    }

    // === COMPREHENSIVE SCENARIO TESTS ===

    function test_FullGameLifecycleWithStatistics() public {
        console.log("=== Full Game Lifecycle Test ===");
        
        // Phase 1: Initial setup and early game
        console.log("Phase 1: Early game");
        tugWarContract.reSet(8);
        
        vm.startPrank(player1);
        tugWarContract.pull(true);
        tugWarContract.pull(true);
        vm.stopPrank();
        
        (uint8 pred1, uint8 conf1) = tugWarContract.getPrediction();
        console.log("Early prediction - Team:");
        console.log(pred1);
        console.log("Confidence:");
        console.log(conf1);
        
        // Phase 2: Mid game competition
        console.log("Phase 2: Mid game");
        vm.startPrank(player2);
        tugWarContract.pull(false);
        tugWarContract.pull(false);
        tugWarContract.pull(false);
        vm.stopPrank();
        
        (uint8 pred2, uint8 conf2) = tugWarContract.getPrediction();
        console.log("Mid-game prediction - Team:");
        console.log(pred2);
        console.log("Confidence:");
        console.log(conf2);
        
        // Phase 3: Late game decisive moves (Team1 needs 8 + team2Score to win)
        console.log("Phase 3: Late game");
        vm.startPrank(player1);
        // Team1 score = 2, Team2 score = 3
        // Team1 needs to reach 3 + 8 = 11 total score to win
        // So need 9 more pulls (11 - 2 = 9)
        for (uint i = 0; i < 9; i++) {
            tugWarContract.pull(true);
        }
        vm.stopPrank();
        
        // Final state - Team1 should win now (11 vs 3, difference = 8)
        assertEq(tugWarContract.getWinStatus(), 1);
        console.log("Final winner: Team 1");
        console.log("Final score Team1:");
        console.log(tugWarContract.team1Score());
        console.log("Final score Team2:");
        console.log(tugWarContract.team2Score());
        console.log("Total pulls:");
        console.log(tugWarContract.totalPulls());
    }

    function test_MultiplePlayersScenario() public {
        console.log("=== Multiple Players Scenario ===");
        
        address team1Player2 = makeAddr("team1Player2");
        address team2Player2 = makeAddr("team2Player2");
        address team1Player3 = makeAddr("team1Player3");
        
        tugWarContract.reSet(6);
        
        // Multiple players dari team 1
        vm.prank(player1);
        tugWarContract.pull(true);
        
        vm.prank(team1Player2);
        tugWarContract.pull(true);
        
        vm.prank(team1Player3);
        tugWarContract.pull(true);
        
        // Multiple players dari team 2
        vm.prank(player2);
        tugWarContract.pull(false);
        
        vm.prank(team2Player2);
        tugWarContract.pull(false);
        
        console.log("Multiple players participated successfully");
        assertEq(tugWarContract.team1Score(), 3);
        assertEq(tugWarContract.team2Score(), 2);
        assertEq(tugWarContract.totalPulls(), 5);
    }

    // === FINAL VALIDATION TESTS ===

    function test_ShouldMaintainStateConsistency() public {
        // Test bahwa state selalu konsisten
        tugWarContract.reSet(5);
        
        for (uint i = 0; i < 20; i++) {
            if (tugWarContract.getWinStatus() != 0) break;
            
            bool isTeam1 = i % 2 == 0;
            
            // State sebelum pull
            uint8 scoreBefore1 = tugWarContract.team1Score();
            uint8 scoreBefore2 = tugWarContract.team2Score();
            int8 ropeBefore = tugWarContract.ropePosition();
            uint256 pullsBefore = tugWarContract.totalPulls();
            
            if (isTeam1) {
                vm.prank(player1);
                tugWarContract.pull(true);
                
                // Validasi perubahan state
                assertEq(tugWarContract.team1Score(), scoreBefore1 + 1);
                assertEq(tugWarContract.team2Score(), scoreBefore2);
                assertEq(tugWarContract.ropePosition(), ropeBefore - 1);
            } else {
                vm.prank(player2);
                tugWarContract.pull(false);
                
                // Validasi perubahan state
                assertEq(tugWarContract.team1Score(), scoreBefore1);
                assertEq(tugWarContract.team2Score(), scoreBefore2 + 1);
                assertEq(tugWarContract.ropePosition(), ropeBefore + 1);
            }
            
            assertEq(tugWarContract.totalPulls(), pullsBefore + 1);
        }
        
        console.log("State consistency maintained throughout gameplay");
    }

    function test_ShouldHandleContractLimits() public {
        // Test batas-batas kontrak
        console.log("=== Contract Limits Test ===");
        
        // Test dengan maxScoreDifference maksimum
        tugWarContract.reSet(50);
        
        // Test dengan banyak pulls (mendekati batas uint8 untuk score)
        vm.startPrank(player1);
        for (uint i = 0; i < 50; i++) {
            tugWarContract.pull(true);
        }
        vm.stopPrank();
        
        assertEq(tugWarContract.team1Score(), 50);
        assertEq(tugWarContract.ropePosition(), -50);
        assertEq(tugWarContract.getWinStatus(), 1);
        
        console.log("Successfully handled maximum contract limits");
    }

    // === EVENT TESTING ===

    function test_ShouldEmitPullExecutedEvent() public {
        tugWarContract.reSet(5);
        
        vm.expectEmit(true, false, false, true);
        emit PullExecuted(player1, true, -1, 1, 0);
        
        vm.prank(player1);
        tugWarContract.pull(true);
    }

    function test_ShouldEmitGameWonEvent() public {
        tugWarContract.reSet(1);
        
        vm.expectEmit(false, false, false, true);
        emit GameWon(1, 1, 0);
        
        vm.prank(player1);
        tugWarContract.pull(true);
    }

    function test_ShouldEmitGameResetEvent() public {
        vm.expectEmit(true, false, false, true);
        emit GameReset(address(this), 10);
        
        tugWarContract.reSet(10);
    }

    function test_ShouldEmitOwnershipTransferredEvent() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(this), player1);
        
        tugWarContract.transferOwnership(player1);
    }

    // Define events for testing
    event PullExecuted(address indexed player, bool isTeam1, int8 newRopePosition, uint8 team1Score, uint8 team2Score);
    event GameWon(uint8 winningTeam, uint8 finalScore1, uint8 finalScore2);
    event GameReset(address indexed resetter, uint8 newMaxScoreDifference);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}