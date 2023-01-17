pragma solidity ^0.8.8;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract pvpEscrow is ReentrancyGuard {
    uint256 public damFee;
    uint256 public devFee;
    uint256 public daoFee;
    uint256 public totalgames = 0;
    uint256 public totalConfirmed = 0;

    mapping(uint256 => gameStruct) public games;
    mapping(address => gameStruct[]) public gamesOf;
    mapping(uint256 => address) public ownerOf;

    enum Status {
        OPEN,
        PENDING,
        DELIVERY,
        CONFIRMED,
        DISPUTTED
    }

    struct gameStruct {
        uint256 gameId;
        uint256 amount;
        uint256 timestamp;
        address owner;
        address provider;
        address winner; 
        address payable escrowWallet;
        Status status;
    }

    event Action (
        uint256 indexed gameId,
        bytes32 actionType,
        Status status,
        address indexed executor
    );

    constructor() public {
        damFee = 5;
        devFee = 3;
        daoFee = 2;
    }

function createLobby(address payable _escrowWallet, uint256 amount) payable external returns (bool) {
    require(msg.value >= amount, "game amount is less than required");
    require(damFee <= 10 && damFee >= 1, "Invalid damFee value");
    require(devFee <= 10 && devFee >= 1, "Invalid devFee value");
    require(daoFee <= 10 && daoFee >= 1, "Invalid daoFee value");

    gameStruct memory game;
    game.gameId = totalgames++;
    game.amount = amount;
    game.timestamp = block.timestamp;
    game.owner = msg.sender;
    game.escrowWallet = _escrowWallet;
    game.status = Status.OPEN;
    games[game.gameId] = game;
    //gamesOf[msg.sender].push(game.gameId);
    ownerOf[game.gameId] = msg.sender;

    emit Action (
        game.gameId,
        "game CREATED",
        Status.OPEN,
        msg.sender
    );
    return true;
}



    function deposit(uint256 gameId, uint256 amount) payable external {
        require(games[gameId].status == Status.OPEN, "Game is not in OPEN status");
        require(msg.value == amount, "Deposit amount does not match specified amount");
        games[gameId].escrowWallet.transfer(amount);
    }

    // function getMyGames() external view returns (uint256[] memory) {
    // return gamesOf[msg.sender];
    // }
    
    function getGameID(uint256 gameId) external view returns (gameStruct memory) {
    return games[gameId];
    }


    function setWinner(uint256 gameId, address winner) external {
        require(games[gameId].status != Status.CONFIRMED && games[gameId].status != Status.DISPUTTED, "Game already confirmed or disputed");
        require(msg.sender == games[gameId].owner, "You are not the owner of the game");
        games[gameId].winner = winner;
        games[gameId].status = Status.CONFIRMED;
        totalConfirmed++;
        emit Action (
            gameId,
            "Winner set",
            Status.CONFIRMED,
            msg.sender
        );
    }

    function releaseFunds(uint256 gameId) external{
        require(msg.sender == games[gameId].owner, "You are not the owner of the game");
        require(games[gameId].status == Status.CONFIRMED, "Game is not confirmed yet");
        require(games[gameId].winner != address(0), "No winner has been set for this game");
        games[gameId].escrowWallet.transfer(games[gameId].amount);
    }
}
