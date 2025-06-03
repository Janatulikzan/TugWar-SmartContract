// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract TugWarContract {
    // Game state variables
    int8 public ropePosition;           // Posisi tali (-127 to 127)
    uint8 public team1Score;            // Skor tim 1 (0-255)
    uint8 public team2Score;            // Skor tim 2 (0-255)
    uint8 public maxScoreDifference;    // Selisih maksimal untuk menang
    address public owner;               // Owner contract
    
    // Game statistics
    uint256 public totalPulls;         // Total tarikan dalam game
    uint256 public gamesPlayed;        // Total game yang dimainkan
    
    // Events untuk logging
    event PullExecuted(address indexed player, bool isTeam1, int8 newRopePosition, uint8 team1Score, uint8 team2Score);
    event GameWon(uint8 winningTeam, uint8 finalScore1, uint8 finalScore2);
    event GameReset(address indexed resetter, uint8 newMaxScoreDifference);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Custom errors untuk gas efficiency
    error GameOver();
    error OnlyOwner();
    error InvalidMaxScoreDifference();
    error GameNotStarted();
    
    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    
    modifier gameActive() {
        if (getWinStatus() != 0) revert GameOver();
        _;
    }
    
    constructor(address _owner) {
        if (_owner == address(0)) {
            owner = msg.sender;
        } else {
            owner = _owner;
        }
        
        maxScoreDifference = 5;  // Default win condition
        ropePosition = 0;
        team1Score = 0;
        team2Score = 0;
        totalPulls = 0;
        gamesPlayed = 0;
        
        emit GameReset(owner, maxScoreDifference);
    }
    
    /**
     * @dev Fungsi utama untuk menarik tali
     * @param isTeam1 true jika tim 1 yang menarik, false untuk tim 2
     */
    function pull(bool isTeam1) public gameActive {
        // Update scores dan rope position
        if (isTeam1) {
            team1Score++;
            ropePosition--;
        } else {
            team2Score++;
            ropePosition++;
        }
        
        totalPulls++;
        
        emit PullExecuted(msg.sender, isTeam1, ropePosition, team1Score, team2Score);
        
        // Cek apakah ada pemenang
        uint8 winStatus = getWinStatus();
        if (winStatus != 0) {
            emit GameWon(winStatus, team1Score, team2Score);
        }
    }
    
    /**
     * @dev Mendapatkan status pemenang
     * @return 0 = game berlanjut, 1 = tim 1 menang, 2 = tim 2 menang
     */
    function getWinStatus() public view returns(uint8) {
        if (team2Score >= maxScoreDifference + team1Score) return 2;
        if (team1Score >= maxScoreDifference + team2Score) return 1;
        return 0;
    }
    
    /**
     * @dev Reset game dengan parameter baru
     * @param _maxScoreDifference Selisih skor maksimal untuk menang
     */
    function reSet(uint8 _maxScoreDifference) public onlyOwner {
        if (_maxScoreDifference == 0 || _maxScoreDifference > 50) {
            revert InvalidMaxScoreDifference();
        }
        
        maxScoreDifference = _maxScoreDifference;
        team1Score = 0;
        team2Score = 0;
        ropePosition = 0;
        totalPulls = 0;
        gamesPlayed++;
        
        emit GameReset(msg.sender, _maxScoreDifference);
    }
    
    /**
     * @dev Transfer ownership ke address baru
     * @param newOwner Address owner baru
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
    
    /**
     * @dev Mendapatkan informasi lengkap game
     * @return currentRopePos Posisi tali saat ini
     * @return score1 Skor tim 1
     * @return score2 Skor tim 2
     * @return maxDiff Selisih maksimal untuk menang
     * @return winner Status pemenang (0=ongoing, 1=team1, 2=team2)
     * @return pulls Total tarikan dalam game ini
     * @return games Total game yang dimainkan
     */
    function getGameInfo() public view returns(
        int8 currentRopePos,
        uint8 score1,
        uint8 score2,
        uint8 maxDiff,
        uint8 winner,
        uint256 pulls,
        uint256 games
    ) {
        return (
            ropePosition,
            team1Score,
            team2Score,
            maxScoreDifference,
            getWinStatus(),
            totalPulls,
            gamesPlayed
        );
    }
    
    /**
     * @dev Mendapatkan statistik tim
     * @param teamNumber 1 untuk tim 1, 2 untuk tim 2
     * @return score Skor tim
     * @return isWinning Apakah tim sedang unggul
     * @return scoreAdvantage Keunggulan skor vs tim lawan
     */
    function getTeamStats(uint8 teamNumber) public view returns(
        uint8 score,
        bool isWinning,
        uint8 scoreAdvantage
    ) {
        require(teamNumber == 1 || teamNumber == 2, "Invalid team number");
        
        if (teamNumber == 1) {
            return (
                team1Score,
                team1Score > team2Score,
                team1Score > team2Score ? team1Score - team2Score : 0
            );
        } else {
            return (
                team2Score,
                team2Score > team1Score,
                team2Score > team1Score ? team2Score - team1Score : 0
            );
        }
    }
    
    /**
     * @dev Cek apakah game dapat dimulai
     * @return canStart True jika game bisa dimulai
     */
    function canStartGame() public view returns(bool canStart) {
        return getWinStatus() == 0;
    }
    
    /**
     * @dev Mendapatkan prediksi pemenang berdasarkan tren
     * @return predictedWinner 0=tie, 1=team1 favored, 2=team2 favored
     * @return confidence Level confidence (0-100)
     */
    function getPrediction() public view returns(uint8 predictedWinner, uint8 confidence) {
        if (totalPulls == 0) return (0, 0);
        
        uint8 scoreDiff;
        if (team1Score > team2Score) {
            scoreDiff = team1Score - team2Score;
            predictedWinner = 1;
        } else if (team2Score > team1Score) {
            scoreDiff = team2Score - team1Score;
            predictedWinner = 2;
        } else {
            return (0, 0);
        }
        
        // Confidence based on score difference and max difference
        confidence = (scoreDiff * 100) / maxScoreDifference;
        if (confidence > 100) confidence = 100;
        
        return (predictedWinner, confidence);
    }
}