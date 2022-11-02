//SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";



/// @title EXC-GAME-CONTRACT
/// @author Oleanji
/// @notice A contract for gaming and dex exp

contract GameToken is ERC20, VRFConsumerBaseV2 {

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error UpkeepNotNeeded();

    /// -----------------------------------------------------------------------
    /// Structs
    /// -----------------------------------------------------------------------

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

    /// -----------------------------------------------------------------------
    /// Global Variables
    /// -----------------------------------------------------------------------

    using Counters for Counters.Counter;
    Counters.Counter internal numOfAllPlayers;
    uint gameEntryReward = 200;
    uint constant gameFee = 150;

    uint spinBoardPrice = 180;

    uint boardItems = 0;
    address[] public PeopleWhospinned;

    //address of the deployer
    address ownerAddress;

    ////Chainlink vrf Vars
    address vrfCoordinator;
    // = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;

    bytes32 keyHash;
    // =0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

    uint32 callbackGasLimit;
    //  = 100000;

    uint16 requestConfirmations= 3;

    uint32 numWords = 1;

    uint256 public randomLuck;
    address public winner;
    uint256 public requestId;
    address s_owner;

    VRFCoordinatorV2Interface COORDINATOR;

    uint64 subscriptionId;



    /// -----------------------------------------------------------------------
    /// Mapping
    /// -----------------------------------------------------------------------

    mapping(address => bool) private areyouAPlayer;
    mapping(address => bool) private spinned;
    mapping(uint => Players) private idOfPlayers;
    mapping(address => uint) private addressOfPlayers;
       


    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------
    constructor(
        uint _totalSupply,
        uint64 subscriptionIdOfVrf,
        uint items_on_board,
        address s_vrfCoordinator, 
        bytes32 s_keyHash,
        uint32 s_callbackGasLimit,   
    ) VRFConsumerBaseV2(s_vrfCoordinator) ERC20("EXCGameToken", EGT") {
        ownerAddress = msg.sender;
        vrfCoordinator = s_vrfCoordinator;
        keyHash=s_keyHash;
        callbackGasLimit =s_callbackGasLimit;
        boardItems = items_on_board;
        uint amount = _totalSupply * 10**18;
        _mint(ownerAddress, amount);
        COORDINATOR = VRFCoordinatorV2Interface(s_vrfCoordinator);
        subscriptionIdOfVrf = subscriptionId;
        s_owner = msg.sender;
    }


    /// -----------------------------------------------------------------------
    ///  functions
    /// -----------------------------------------------------------------------


    function NewPlayer(string memory _date, string memory _name)
        public
        payable
    {
        require(areyouAPlayer[msg.sender] == false, "you are already a player");
        numOfAllPlayers.increment();
        uint newPlayersRewards = gameEntryReward * 10**18;
        _mint(msg.sender, newPlayersRewards);
        uint[] memory _scores = new uint[](0);
        uint currentplayerId = numOfAllPlayers.current();
        idOfPlayers[currentplayerId] = Players(
        currentplayerId,
            _name,
            msg.sender,
            0,
            _date,
            gameEntryReward,
            _scores,
            0,
            0,
        );
        addressOfPlayers[msg.sender] = currentplayerId;
        areyouAPlayer[msg.sender] = true;

        emit PlayerJoined(
            _name,
            msg.sender,
            currentplayerId,
            0,
            _date,
            gameEntryReward,
            _scores,
            0,
            false
        );
    }



    function areYouAPlayer() public view returns (bool) {
        return (areyouAPlayer[msg.sender]);
    }



    function GetAplayerdetails() public view returns (Players[] memory) {
        Players[] memory thisMember = new Players[](1);
        uint _theId = addressOfPlayers[msg.sender];
        Players storage _member = idOfPlayers[_theId];
        thisMember[0] = _member;
        return thisMember;
    }



    function gameEnded(
        uint _id,
        uint score,
        uint rewardtokens
    ) public {
        uint AllPlayer = numOfAllPlayers.current();
        uint addedrewards;
        for (uint i = 0; i < AllPlayer; i++) {
            if (_id == idOfPlayers[i + 1].PlayersId) {
                uint currentTokens = idOfPlayers[i + 1].TokenOwned;
                addedrewards = currentTokens + rewardtokens;
                idOfPlayers[i + 1].TokenOwned = addedrewards;
                idOfPlayers[i + 1].MyGames += 1;
                idOfPlayers[i + 1].Scores.push(score);
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
        spinned[msg.sender] = true;
        uint AllPlayer = numOfAllPlayers.current();
        for (uint i = 0; i < AllPlayer; i++) {
            if (msg.sender == idOfPlayers[i + 1].PlayersAddress) {
                idOfPlayers[i + 1].spinning = true;
            }
        }
        PeopleWhospinned.push(msg.sender);

        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }




    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        randomLuck = (randomWords[0] % boardItems) + 1;
        ResetApplication();
    }



    function remove(uint index) public {
        PeopleWhospinned[index] = PeopleWhospinned[PeopleWhospinned.length - 1];
        PeopleWhospinned.pop();
    }




    function ResetApplication() public {
        for (uint i = 0; i < PeopleWhospinned.length; i++) {
            address currentAddress = PeopleWhospinned[i];
            if (
                areyouAPlayer[currentAddress] == true &&
                spinned[currentAddress] == true
            ) {
                uint _id = addressOfPlayers[currentAddress];
                idOfPlayers[_id].spinning = false;
                spinned[currentAddress] = false;
                uint newMintingAmount = 10000 * 10**18;
                _mint(currentAddress, newMintingAmount);
                remove(i);
            }
        }
    }

    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}



    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
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

}
