// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is CodeConstants, Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;
    address vrfCoordinatorV2_5;
    LinkToken link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        link = LinkToken(config.link);
        vrfCoordinatorV2_5 = config.vrfCoordinator;
        link = LinkToken(config.link);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(
                subscriptionId,
                LINK_BALANCE
            );
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
    }

    function RaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertWhenYouDontPayEnough() public {
        // arrange
        vm.prank(PLAYER);
        // act // assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        //arrange
        vm.prank(PLAYER);
        //act
        raffle.enterRaffle{value: entranceFee};
        //assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersWhileRaffleIsCalculating() public {
        // arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee};
        vm.warp(block.timestamp + interval + 1); // warp is a cheatcode to customize the time
        vm.roll(block.number + 1); // roll changes the block.number
        raffle.performUpKeep("");
        //Act // assert
        vm.expectRevert(Raffle.Raffle_Raffle_NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        // arrange
        vm.warp(block.timestamp + interval + 1); // warp is a cheatcode to customize the time
        vm.roll(block.number + 1); // roll changes the block.number
        // act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsntOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee};
        vm.warp(block.timestamp + interval + 1); // warp is a cheatcode to customize the time
        vm.roll(block.number + 1); // roll changes the block.number
        raffle.performUpKeep("");
        // act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(!upKeepNeeded);
    }

    // challenge: write some tests myself

    function testPerformUpKeepCanOnlyRunWhenCheckUpKeepIstTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee};
        vm.warp(block.timestamp + interval + 1); // warp is a cheatcode to customize the time
        vm.roll(block.number + 1); // roll changes the block.number
        //ACT/assert
        raffle.performUpKeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        // act/ assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpKeep("");
    }

    modifier raffleEntered() {
        //arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee};
        vm.warp(block.timestamp + interval + 1); // warp is a cheatcode to customize the time
        vm.roll(block.number + 1); // roll changes the block.number
        _;
    } // good thing if need to do this part everytime just add a modifier(bestpractice)

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        //act
        vm.recordLogs(); // records logs of the performupkeep
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs(); // the entries array is where the logs will be recorded
        bytes32 requestId = entries[1].topics[1];

        // assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
            _;
        }
    }

    function testFulFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEntered {
        // arrange // act // assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );

        // lets do a fuzz test to not do that for every random word called.
    }

    function testFulFillrandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
    {
        // arrange
        uint256 additionalEntrances = 3; // 4 total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address newPlayer = address(uint160(i)); // converting a number into an address.
            hoax(newPlayer, 1 ether); // sets up a prank in an address that has ether
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp(); // create an get function first to get the lasttimestamp
        uint256 winnerStartingBalance = expectedWinner.balance;
        // act
        vm.recordLogs(); // records logs of the performupkeep
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs(); // the entries array is where the logs will be recorded
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1); // * is times.

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp); // practice is the mother of skill.
    }
}
