// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {OneNumber} from "../src/OneNumber.sol";

contract OneNumberTest is Test {
    OneNumber public oneNumber;

    function setUp() public {
        oneNumber = new OneNumber();
    }

    function test_NewGame() public {
        uint72 cost = 100;
        uint32 blindDuration = 10;
        uint32 revealDuration = 20;
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        (uint72 actualCost,uint32 actualBlindDur,uint32 actualrevealDur,,) = oneNumber.games(gameId);
        assertEq(actualCost, cost);
        assertEq(actualBlindDur, blindDuration);
        assertEq(actualrevealDur, revealDuration);
    }

    function testFuzz_NewGame(uint72 cost, uint32 blindDuration, uint32 revealDuration) public {
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        (uint72 actualCost,uint32 actualBlindDur,uint32 actualrevealDur,,) = oneNumber.games(gameId);
        assertEq(actualCost, cost);
        assertEq(actualBlindDur, blindDuration);
        assertEq(actualrevealDur, revealDuration);
    }

    function test_SetBlindedNumber() public {
        uint72 cost = 100;
        uint32 blindDuration = 10;
        uint32 revealDuration = 20;
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        bytes32 blindedNumber = bytes32("0x1234");
        oneNumber.setBlindedNumber{value: cost}(gameId, blindedNumber);
        bytes32 actualBlindedNumber = oneNumber.getBlindedNumber(gameId, address(this));
        assertEq(actualBlindedNumber, blindedNumber);
    }

    function testFuzz_SetBlindedNumber(uint72 cost, uint32 blindDuration, uint32 revealDuration) public {
        vm.assume(cost < 2^72-1);
        vm.assume(blindDuration < 2^32-1);
        vm.assume(revealDuration < 2^32-1);
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        bytes32 blindedNumber = bytes32("0x1234");
        oneNumber.setBlindedNumber{value: cost}(gameId, blindedNumber);
        bytes32 actualBlindedNumber = oneNumber.getBlindedNumber(gameId, address(this));
        assertEq(actualBlindedNumber, blindedNumber);
    }

    function test_RevealNumber() public {
        uint72 cost = 100;
        uint32 blindDuration = 10;
        uint32 revealDuration = 20;
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        string memory secret = "secret";
        uint number = 123;
        bytes32 blindedNumber = keccak256(abi.encodePacked(number, secret));
        oneNumber.setBlindedNumber{value: cost}(gameId, blindedNumber);
        (,,,uint start,) = oneNumber.games(gameId);
        vm.warp(start + blindDuration + 1);
        oneNumber.revealNumber(gameId, number, secret);
        (address player,uint96 shouldBeOne) = oneNumber.getRevealedNumber(gameId, number);
        assertEq(player, address(this));
        assertEq(shouldBeOne, 1);
    }

    function testFuzz_RevealNumber(uint72 cost, uint32 blindDuration, uint32 revealDuration, string memory secret, uint number) public {
        vm.assume(cost < 2^72-1);
        vm.assume(blindDuration < 2^32-1);
        vm.assume(revealDuration < 2^32-1);
        vm.assume(blindDuration < revealDuration);
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        bytes32 blindedNumber = keccak256(abi.encodePacked(number, secret));
        oneNumber.setBlindedNumber{value: cost}(gameId, blindedNumber);
        (,,,uint start,) = oneNumber.games(gameId);
        vm.warp(start + blindDuration + 1);
        oneNumber.revealNumber(gameId, number, secret);
        (address player, uint96 shouldBeOne) = oneNumber.getRevealedNumber(gameId, number);
        assertEq(player, address(this));
        assertEq(shouldBeOne, 1);
    }

    function test_EndGame() public {
        address player = address(0x1001);
        uint72 cost = 100;
        uint32 blindDuration = 10;
        uint32 revealDuration = 20;
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        string memory secret = "secret";
        uint number = 123;
        bytes32 blindedNumber = keccak256(abi.encodePacked(number, secret));
        vm.deal(player, cost);
        vm.startPrank(player);
        oneNumber.setBlindedNumber{value: cost}(gameId, blindedNumber);
        (,,,uint start,) = oneNumber.games(gameId);
        vm.warp(start + blindDuration + 1);
        oneNumber.revealNumber(gameId, number, secret);
        vm.warp(start + blindDuration + revealDuration + 1);
        (,,,,uint88 beforePrize) = oneNumber.games(gameId);
        assertEq(beforePrize, cost);
        oneNumber.endGame(gameId);
        (,,,,uint88 afterPrize) = oneNumber.games(gameId);
        assertEq(afterPrize, 0);
        assertEq(player.balance, beforePrize);
    }

    function test_EndGame_NoPlayers() public {
        uint72 cost = 100;
        uint32 blindDuration = 10;
        uint32 revealDuration = 20;
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        string memory secret = "secret";
        uint number = 123;
        bytes32 blindedNumber = keccak256(abi.encodePacked(number, secret));
        oneNumber.setBlindedNumber{value: cost}(gameId, blindedNumber);
        (,,,uint start,) = oneNumber.games(gameId);
        vm.warp(start + blindDuration + revealDuration + 1);
        vm.expectRevert(OneNumber.NoPlayers.selector);
        oneNumber.endGame(gameId);
    }

    function test_EndGame_EndGameTooEarly() public {
        uint72 cost = 100;
        uint32 blindDuration = 10;
        uint32 revealDuration = 20;
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        string memory secret = "secret";
        uint number = 123;
        bytes32 blindedNumber = keccak256(abi.encodePacked(number, secret));
        oneNumber.setBlindedNumber{value: cost}(gameId, blindedNumber);
        vm.expectRevert(OneNumber.EndGameTooEarly.selector);
        oneNumber.endGame(gameId);
    }

    function test_EndGame_GameEnded() public {
        address player = address(0x1001);
        uint72 cost = 100;
        uint32 blindDuration = 10;
        uint32 revealDuration = 20;
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        string memory secret = "secret";
        uint number = 123;
        bytes32 blindedNumber = keccak256(abi.encodePacked(number, secret));
        vm.deal(player, cost);
        vm.startPrank(player);
        oneNumber.setBlindedNumber{value: cost}(gameId, blindedNumber);
        (,,,uint start,) = oneNumber.games(gameId);
        vm.warp(start + blindDuration + 1);
        oneNumber.revealNumber(gameId, number, secret);
        vm.warp(start + blindDuration + revealDuration + 1);
        oneNumber.endGame(gameId);
        vm.expectRevert(OneNumber.GameEnded.selector);
        oneNumber.endGame(gameId);
    }

    function test_EndGame_TenThousandPlayers_TenThousandUniqueNumbers() public {
        uint72 cost = 100;
        uint32 blindDuration = 10;
        uint32 revealDuration = 20;
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        string memory secret = "secret";
        uint[] memory numbers = new uint[](10000);
        for (uint i; i < 10000; i++) {
            // This is to make it so that when endGame is called every number is lower than the last - worst case scenario
            numbers[i] = 10000 - i;
        }
        for (uint i = 0; i < 10000; i++) {
            uint number = numbers[i];
            bytes32 blindedNumber = keccak256(abi.encodePacked(number, secret));

            address player = address(uint160(1000 + i));
            vm.deal(player, cost);
            vm.startPrank(player);
            oneNumber.setBlindedNumber{value: cost}(gameId, blindedNumber);
        }
        (,,,uint start,) = oneNumber.games(gameId);
        vm.warp(start + blindDuration + 1);
        for (uint i = 0; i < 10000; i++) {
            uint number = numbers[i];
            address player = address(uint160(1000 + i));
            vm.startPrank(player);
            oneNumber.revealNumber(gameId, number, secret);
        }
        vm.warp(start + blindDuration + revealDuration + 1);
        oneNumber.endGame(gameId);
    }

    function test_EndGame_TenThousandPlayers_TwoThousandUniqueNumbers() public {
        uint72 cost = 100;
        uint32 blindDuration = 10;
        uint32 revealDuration = 20;
        uint gameId = oneNumber.newGame(cost, blindDuration, revealDuration);
        string memory secret = "secret";
        uint[] memory numbers = new uint[](2000);
        for (uint i; i < 2000; i++) {
            // This is to make it so that when endGame is called every number is lower than the last - worst case scenario
            numbers[i] = 2000 - i;
        }
        for (uint i = 0; i < 10000; i++) {
            uint number = numbers[i % 2000];
            bytes32 blindedNumber = keccak256(abi.encodePacked(number, secret));

            address player = address(uint160(1000 + i));
            vm.deal(player, cost);
            vm.startPrank(player);
            oneNumber.setBlindedNumber{value: cost}(gameId, blindedNumber);
        }
        (,,,uint start,) = oneNumber.games(gameId);
        vm.warp(start + blindDuration + 1);
        for (uint i = 0; i < 10000; i++) {
            uint number = numbers[i % 2000];
            address player = address(uint160(1000 + i));
            vm.startPrank(player);
            oneNumber.revealNumber(gameId, number, secret);
        }
        vm.warp(start + blindDuration + revealDuration + 1);
        oneNumber.endGame(gameId);
    }
}
