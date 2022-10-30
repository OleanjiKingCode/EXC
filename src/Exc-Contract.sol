//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "hardhat/console.sol";

error UpkeepNotNeeded();

contract GameToken is ERC20, VRFConsumerBaseV2 {
    using Counters for Counters.Counter;
    Counters.Counter internal numOfAllPlayers;
    uint gameEntryReward = 200;
    uint constant gameFee = 150;

    uint spinBoardPrice = 180;

    uint boardItems = 0;

    struct Players {
        uint playersId;
        string userName;
        address playersAddress;
        uint gamesPlayed;
        string dateJoined;
        uint tokensOwned;
        uint[] scores;
        uint highestScore;
        // bool spinning;
    }

    address[] public PeopleWhoSpinned;

    event PlayerJoined(
        string username,
        address player,
        uint playerId,
        uint noOfGames,
        string dateJoined,
        uint rewardTokensOwned,
        uint[] Scores,
        uint highestScore,
        bool spinning
    );

    event GameEnded(
        uint PlayerId,
        address playersAddress,
        uint tokensEarned,
        uint Score
    );

    mapping(address => bool) private areyouAPlayer;
    mapping(address => bool) private Spinned;
    mapping(uint => Players) private IdOfPlayers;
    mapping(address => uint) private AddressOfPlayers;
    uint mintToNewPlayers = 130;

    VRFCoordinatorV2Interface COORDINATOR;

    uint64 s_subscriptionId;

    address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;

    bytes32 keyHash =
        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

    uint32 callbackGasLimit = 100000;

    uint16 requestConfirmations = 3;

    uint32 numWords = 1;

    uint256 public s_randomLuck;
    address public winner;
    uint256 public s_requestId;
    address s_owner;
    //address of the deployer
    address ownerAddress;
    uint public lastTimeStamp;

    constructor(
        uint _totalSupply,
        uint64 subscriptionId,
        uint items_on_board
    ) VRFConsumerBaseV2(vrfCoordinator) ERC20("EXCGameToken", EGT") {
        ownerAddress = msg.sender;
        no_of_items_on_board = items_on_board;
        uint amount = _totalSupply * 10**18;
        _mint(ownerAddress, amount);
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
        s_owner = msg.sender;
        lastTimeStamp = block.timestamp;
    }

    function NewPlayer(string memory _date, string memory _name)
        public
        payable
    {
        require(areyouAPlayer[msg.sender] == false, "you are already a player");

        NumOfAllPlayers.increment();
        uint value_given_to_new_players = mintToNewPlayers * 10**18;
        _mint(msg.sender, value_given_to_new_players);
        uint[] memory _scores = new uint[](0);
        uint currentplayerId = NumOfAllPlayers.current();
        IdOfPlayers[currentplayerId] = Players(
            _name,
            msg.sender,
            currentplayerId,
            0,
            _date,
            mintToNewPlayers,
            _scores,
            0,
            false
        );
        AddressOfPlayers[msg.sender] = currentplayerId;

        areyouAPlayer[msg.sender] = true;

        emit PlayerJoined(
            _name,
            msg.sender,
            currentplayerId,
            0,
            _date,
            mintToNewPlayers,
            _scores,
            0,
            false
        );
    }

    function areYouAPlayer() public view returns (bool) {
        bool isAPlayer = areyouAPlayer[msg.sender];
        return isAPlayer;
    }

    function GetAplayerdetails() public view returns (Players[] memory) {
        Players[] memory ThisMember = new Players[](1);
        uint _theId = AddressOfPlayers[msg.sender];
        Players storage _member = IdOfPlayers[_theId];
        ThisMember[0] = _member;
        return ThisMember;
    }

    function gameEnded(
        uint _id,
        uint score,
        uint rewardtokens
    ) public {
        uint AllPlayer = NumOfAllPlayers.current();
        uint addedrewards;
        for (uint i = 0; i < AllPlayer; i++) {
            if (_id == IdOfPlayers[i + 1].PlayersId) {
                uint currentTokens = IdOfPlayers[i + 1].TokenOwned;
                addedrewards = currentTokens + rewardtokens;
                IdOfPlayers[i + 1].TokenOwned = addedrewards;
                IdOfPlayers[i + 1].MyGames += 1;
                IdOfPlayers[i + 1].Scores.push(score);
            }
        }
        uint256 Mintmore = 5000;
        if (balanceOf(ownerAddress) < Mintmore) {
            uint newMintingAmount = 10000 * 10**18;
            _mint(ownerAddress, newMintingAmount);
        }
        uint256 rewardtokensAward = rewardtokens * 10**18;
        // this is where the new members are given tokens and where they are removed from the deployer
        _mint(msg.sender, rewardtokensAward);
        _burn(ownerAddress, rewardtokensAward);

        emit GameEnded(_id, msg.sender, rewardtokens, score);
    }

    function SpinBoard(uint pricePaid) public {
        require(
            pricePaid >= spinBoardPrice,
            "The price for the spin board is not enough"
        );
        require(areyouAPlayer[msg.sender] == true, "you are not a player");
        Spinned[msg.sender] = true;
        uint AllPlayer = NumOfAllPlayers.current();
        for (uint i = 0; i < AllPlayer; i++) {
            if (msg.sender == IdOfPlayers[i + 1].PlayersAddress) {
                IdOfPlayers[i + 1].spinning = true;
            }
        }
        console.log("first");
        PeopleWhoSpinned.push(msg.sender);

        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        console.log("last");
        s_randomLuck = (randomWords[0] % no_of_items_on_board) + 1;
        console.log(s_randomLuck);
        ResetApplication();
    }

    function remove(uint index) public {
        PeopleWhoSpinned[index] = PeopleWhoSpinned[PeopleWhoSpinned.length - 1];
        PeopleWhoSpinned.pop();
    }

    function ResetApplication() public {
        for (uint i = 0; i < PeopleWhoSpinned.length; i++) {
            address currentAddress = PeopleWhoSpinned[i];
            if (
                areyouAPlayer[currentAddress] == true &&
                Spinned[currentAddress] == true
            ) {
                uint _id = AddressOfPlayers[currentAddress];
                IdOfPlayers[_id].spinning = false;
                Spinned[currentAddress] = false;
                uint newMintingAmount = 10000 * 10**18;
                _mint(currentAddress, newMintingAmount);
                remove(i);
            }
        }
    }

    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
