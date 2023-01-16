pragma solidity ^0.8.8;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract pvpEscrow is ReentrancyGuard {
    address public escAcc;
    uint256 public escBal;
    uint256 public damFee;
    uint256 public devFee;
    uint256 public daoFee;
    uint256 public totalgames = 0;
    uint256 public totalConfirmed = 0;
    uint256 public totalDisputed = 0;

    mapping(uint256 => gameStruct) private games;
    mapping(address => gameStruct[]) private gamesOf;
    mapping(address => mapping(uint256 => bool)) public requested;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => Available) public isAvailable;

    enum Status {
        OPEN,
        PENDING,
        DELIVERY,
        CONFIRMED,
        DISPUTTED,
        REFUNDED,
        WITHDRAWED
    }

    enum Available { NO, YES }

    struct gameStruct {
        uint256 gameId;
        uint256 amount;
        uint256 timestamp;
        address owner;
        address provider;
        Status status;
    }

    event Action (
        uint256 gameId,
        string actionType,
        Status status,
        address indexed executor
    );

    constructor() public {
        escAcc = msg.sender;
        escBal = 0;
        damFee = 5;
        devFee = 3;
        daoFee = 2;
    }

    function createLobby(uint256 amount) payable external returns (bool) {
        require(msg.value >= amount, "game amount is less than required");
        require(damFee <= 10 && damFee >= 1, "Invalid damFee value");
        require(devFee <= 10 && devFee >= 1, "Invalid devFee value");
        require(daoFee <= 10 && daoFee >= 1, "Invalid daoFee value");

        uint256 gameId = totalgames++;
        gameStruct storage game = games[gameId];

        game.gameId = gameId;
        game.amount = msg.value;
        game.timestamp = block.timestamp;
        game.owner = msg.sender;
        game.status = Status.OPEN;

        gamesOf[msg.sender].push(game);
        ownerOf[gameId] = msg.sender;
        isAvailable[gameId] = Available.YES;
        escBal += msg.value;

        emit Action (
            gameId,
            "game CREATED",
            Status.OPEN,
            msg.sender
        );
        return true;
    }

    function getMyGames() external view returns (gameStruct[] memory) {
    return gamesOf[msg.sender];
    }
}