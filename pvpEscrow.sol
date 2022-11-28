// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract pvpEscrow is ReentrancyGuard {
    address public escAcc;
    uint256 public escBal;
    uint256 public escAvailBal;
    uint256 public damFee = 5;
    uint256 public devFee = 3;
    uint256 public daoFee = 2;
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
        bool provided;
        bool confirmed;
    }

    event Action (
        uint256 gameId,
        string actionType,
        Status status,
        address indexed executor
    );

    constructor(uint256 _damFee) {
        escAcc = msg.sender;
        escBal = 0;
        escAvailBal = 0;
        damFee = _damFee;
    }

    function createLobby(uint256 amount) payable external returns (bool){
        require(msg.value > 0 ether, "game cannot be zero ethers");

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

    function getgames()
        external
        view
        returns (gameStruct[] memory props) {
        props = new gameStruct[](totalgames);

        for (uint256 i = 0; i < totalgames; i++) {
            props[i] = games[i];
        }
    }

    function getgame(uint256 gameId)
        external
        view
        returns (gameStruct memory) {
        return games[gameId];
    }

    function mygames()
        external
        view
        returns (gameStruct[] memory) {
        return gamesOf[msg.sender];
    }

    function requestgame(uint256 gameId) external returns (bool) {
        require(msg.sender != ownerOf[gameId], "Owner not allowed");
        require(isAvailable[gameId] == Available.YES, "game not available");

        requested[msg.sender][gameId] = true;

        emit Action (
            gameId,
            "REQUESTED",
            Status.OPEN,
            msg.sender
        );

        return true;
    }

    function approveRequest(
        uint256 gameId,
        address provider
    ) external returns (bool) {
        require(msg.sender == ownerOf[gameId], "Only owner allowed");
        require(isAvailable[gameId] == Available.YES, "game not available");
        require(requested[provider][gameId], "Player not on the list");

        isAvailable[gameId] == Available.NO;
        games[gameId].status = Status.PENDING;
        games[gameId].provider = provider;

        emit Action (
            gameId,
            "APPROVED",
            Status.PENDING,
            msg.sender
        );

        return true;
    }

    function performDelivery(uint256 gameId) external returns (bool) {
        require(msg.sender == games[gameId].provider, "Game prize not awarded to you");
        require(!games[gameId].provided, "Game prize already provided");
        require(!games[gameId].confirmed, "Game prize confirmed");

        games[gameId].provided = true;
        games[gameId].status = Status.DELIVERY;

        emit Action (
            gameId,
            "DELIVERY INTIATED",
            Status.DELIVERY,
            msg.sender
        );

        return true;
    }

    function confirmDelivery(
        uint256 gameId,
        bool provided
    ) external returns (bool) {
        require(msg.sender == ownerOf[gameId], "Only owner allowed");
        require(games[gameId].provided, "Game prize not provided");
        require(games[gameId].status != Status.REFUNDED, "Already refunded, create a new game");

        if(provided) {
            uint256 fee = (games[gameId].amount * damFee) / 100;
            payTo(games[gameId].provider, (games[gameId].amount - fee));
            escBal -= games[gameId].amount;
            escAvailBal += fee;

            games[gameId].confirmed = true;
            games[gameId].status = Status.CONFIRMED;
            totalConfirmed++;
        }else {
           games[gameId].status = Status.DISPUTTED; 
        }

        emit Action (
            gameId,
            "DISPUTTED",
            Status.DISPUTTED,
            msg.sender
        );

        return true;
    }

    function refundgame(uint256 gameId) external returns (bool) {
        require(msg.sender == escAcc, "Only Escrow allowed");
        require(!games[gameId].confirmed, "Game prize already provided");

        payTo(games[gameId].owner, games[gameId].amount);
        escBal -= games[gameId].amount;
        games[gameId].status = Status.REFUNDED;
        totalDisputed++;

        emit Action (
            gameId,
            "REFUNDED",
            Status.REFUNDED,
            msg.sender
        );

        return true;
    }

    function withdrawFund(
        address to,
        uint256 amount
    ) external returns (bool) {
        require(msg.sender == escAcc, "Only Escrow allowed");
        require(amount > 0 ether && amount <= escAvailBal, "Zero withdrawal not allowed");

        payTo(to, amount);
        escAvailBal -= amount;

        emit Action (
            block.timestamp,
            "WITHDRAWED",
            Status.WITHDRAWED,
            msg.sender
        );

        return true;
    }

    function payTo(
        address to, 
        uint256 amount
    ) internal returns (bool) {
        (bool success,) = payable(to).call{value: amount}("");
        require(success, "Payment failed");
        return true;
    }
}