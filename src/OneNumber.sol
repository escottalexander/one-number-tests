// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.0;

contract OneNumber {
    struct NumberData {
        address player;
        uint96 count;
    } 

    struct Game {
        uint72 cost;
        uint32 blindDuration;
        uint32 revealDuration;
        uint32 start;
        uint88 prize;
        mapping(address => bytes32) blindedNumbers;
        mapping(uint => NumberData) revealedNumbersData;
        uint[] revealedNumbers;
    }

    uint public numGames;
    mapping(uint => Game) public games;

    error InvalidCost();
    error InvalidGame();
    error BlindedNumberTooLate();
    error OnlyOneNumber();
    error RevealTooEarly();
    error RevealTooLate();
    error RevealIncorrect();
    error BlindedNumberMissing();
    error EndGameTooEarly();
    error GameEnded();
    error NoPlayers();

    function newGame(uint72 cost, uint32 blindDuration, uint32 revealDuration) external returns (uint gameId) {
        gameId = numGames++;

        Game storage game = games[gameId];

        game.cost = cost;
        game.blindDuration = blindDuration;
        game.revealDuration = revealDuration;
        game.start = uint32(block.timestamp);

        return gameId;
    }

    function setBlindedNumber(uint gameId, bytes32 blindedNumber) external payable {
        Game storage game = games[gameId];

        if (game.start == 0) {
            revert InvalidGame();
        }

        if (msg.value != game.cost) {
            revert InvalidCost();
        }

        if (block.timestamp > game.start + game.blindDuration) {
            revert BlindedNumberTooLate();
        }

        if (game.blindedNumbers[msg.sender] != 0) {
            revert OnlyOneNumber();
        }

        game.blindedNumbers[msg.sender] = blindedNumber;

        game.prize += uint88(msg.value);
    }

    function revealNumber(uint gameId, uint number, bytes32 secret) external {
        _revealNumber(gameId, number, keccak256(abi.encodePacked(number, secret)));
    }

    function revealNumber(uint gameId, uint number, string memory secret) external {
        _revealNumber(gameId, number, keccak256(abi.encodePacked(number, secret)));
    }

    function _revealNumber(uint gameId, uint number, bytes32 blindedNumber) private {
        Game storage game = games[gameId];

        if (block.timestamp <= game.start + game.blindDuration) {
            revert RevealTooEarly();
        }

        if (block.timestamp > game.start + game.blindDuration + game.revealDuration) {
            revert RevealTooLate();
        }

        bytes32 storedBlindedNumber = game.blindedNumbers[msg.sender];

        if (storedBlindedNumber == 0) {
            revert BlindedNumberMissing();
        }

        if (storedBlindedNumber != blindedNumber) {
            revert RevealIncorrect();
        }

        NumberData storage numberData = game.revealedNumbersData[number];

        if (numberData.player == address(0)) {
            numberData.player = msg.sender;

            game.revealedNumbers.push(number);
        }

        numberData.count++;
    }

    function endGame(uint gameId) external {
        Game storage game = games[gameId];

        if (block.timestamp <= game.start + game.blindDuration + game.revealDuration) {
            revert EndGameTooEarly();
        }

        uint[] memory revealedNumbers = game.revealedNumbers;

        if (revealedNumbers.length == 0) {
            revert NoPlayers();
        }

        if (game.prize == 0) {
            revert GameEnded();
        }

        uint lowestUniqueNumber;
        uint lowestUniqueNumberCount;

        address winner;

        for (uint i = 0; i < revealedNumbers.length; i++) {
            uint number = revealedNumbers[i];

            NumberData memory numberData = game.revealedNumbersData[number];

            uint96 count = numberData.count;

            if ((lowestUniqueNumberCount != 0) && (count > lowestUniqueNumberCount)) {
                continue;
            }
            if (count == lowestUniqueNumberCount) {
                if (number > lowestUniqueNumber) {
                    continue;
                }
            }

            lowestUniqueNumber = number;
            lowestUniqueNumberCount = count;

            winner = numberData.player;
        }

        uint prize = game.prize;

        game.prize = 0;

        payable(winner).transfer(prize);
    }

    function getBlindedNumber(uint gameId, address player) external view returns (bytes32) {
        return games[gameId].blindedNumbers[player];
    }

    function getRevealedNumber(uint gameId, uint number) external view returns (address,uint96) {
        NumberData memory numberData = games[gameId].revealedNumbersData[number];

        return (numberData.player, numberData.count);
    }
}









