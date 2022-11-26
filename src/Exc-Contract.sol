//SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/utils/Counters.sol";
import "chainlink/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "chainlink/v0.8/VRFConsumerBaseV2.sol";

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
        string[] gameNames;
        uint highestScore;
        // bool spinning;
    }

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256 randomWords;
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

    uint256 internal Mintmore = 5000;

    //address of the deployer
    address ownerAddress;

    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    bytes32 keyHash;

    uint32 callbackGasLimit = 100000;

    uint16 requestConfirmations = 3;

    uint32 numWords = 2;

    /// -----------------------------------------------------------------------
    /// Mapping
    /// -----------------------------------------------------------------------

    mapping(address => bool) private areyouAPlayer;
    mapping(address => bool) private spinned;
    mapping(uint => Players) private idOfPlayers;
    mapping(address => uint) private addressOfPlayers;
    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------
    constructor(
        uint _totalSupply,
        uint64 subscriptionIdOfVrf,
        uint items_on_board,
        address s_vrfCoordinator,
        bytes32 s_keyHash
    ) VRFConsumerBaseV2(s_vrfCoordinator) ERC20("EXCGameToken", "EGT") {
        ownerAddress = msg.sender;
        keyHash = s_keyHash;
        boardItems = items_on_board;
        uint amount = _totalSupply * 10**18;
        _mint(ownerAddress, amount);
        COORDINATOR = VRFCoordinatorV2Interface(s_vrfCoordinator);
        s_subscriptionId = subscriptionIdOfVrf;
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
        uint[] memory scores = new uint[](0);
        uint[] memory gameList = new uint[]("");
        uint currentplayerId = numOfAllPlayers.current();
        idOfPlayers[currentplayerId] = Players(
            currentplayerId,
            _name,
            msg.sender,
            0,
            _date,
            gameEntryReward,
            scores,
            gameList,
            0,
            0
        );
        addressOfPlayers[msg.sender] = currentplayerId;
        areyouAPlayer[msg.sender] = true;

        emit PlayerJoined(
            _name,
            msg.sender,
            0,
            _date,
            gameEntryReward,
            scores,
            gameList,
            0,
            0
        );
    }

    function areYouAPlayer() public view returns (bool) {
        return (areyouAPlayer[msg.sender]);
    }

    function GetAplayerdetails() public view returns (Players[] memory) {
        Players[] memory thisMember = new Players[](1);
        uint theId = addressOfPlayers[msg.sender];
        Players storage member = idOfPlayers[theId];
        thisMember[0] = member;
        return thisMember;
    }

    function gameEnded(
        uint id,
        uint score,
        uint rewardtokens,
        string memory gameName
    ) public {
        uint AllPlayer = numOfAllPlayers.current();
        uint addedrewards;
        for (uint i = 0; i < AllPlayer; i++) {
            if (id == idOfPlayers[i + 1].PlayersId) {
                uint currentTokens = idOfPlayers[i + 1].TokenOwned;
                addedrewards = currentTokens + rewardtokens;
                idOfPlayers[i + 1].TokenOwned = addedrewards;
                idOfPlayers[i + 1].MyGames += 1;
                idOfPlayers[i + 1].Scores.push(score);
            }
        }

        if (balanceOf(ownerAddress) < Mintmore) {
            uint newMintingAmount = 10000 * 10**18;
            _mint(ownerAddress, newMintingAmount);
        }
        uint256 rewardtokensAward = rewardtokens * 10**18;
        // this is where the new members are given tokens and where they are removed from the deployer
        _mint(msg.sender, rewardtokensAward);
        _burn(ownerAddress, rewardtokensAward);

        emit GameEnded(id, msg.sender, rewardtokens, score);
    }

    function SpinBoard(uint pricePaid) public returns (uint256 requestId) {
        require(
            pricePaid >= spinBoardPrice,
            "The price for the spin board is not enough"
        );
        require(areyouAPlayer[msg.sender] == true, "you are not a player");
        spinned[msg.sender] = true;
        uint AllPlayer = numOfAllPlayers.current();
        PeopleWhospinned.push(msg.sender);

        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: 0,
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = (_randomWords[0] % boardItems) + 1;
        emit RequestFulfilled(_requestId, _randomWords);
        ResetApplication();
    }

    function getRequestStatus(uint256 _requestId)
        external
        view
        returns (bool fulfilled, uint256 randomWords)
    {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function ResetApplication() public {
        for (uint i = 0; i < PeopleWhospinned.length; i++) {
            address currentAddress = PeopleWhospinned[i];
            if (
                areyouAPlayer[currentAddress] == true &&
                spinned[currentAddress] == true
            ) {
                uint _id = addressOfPlayers[currentAddress];
                spinned[currentAddress] = false;
                uint newMintingAmount = 10000 * 10**18;
                _mint(currentAddress, newMintingAmount);
                remove(i);
            }
        }
    }

    function remove(uint index) public {
        PeopleWhospinned[index] = PeopleWhospinned[PeopleWhospinned.length - 1];
        PeopleWhospinned.pop();
    }

    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
    event PlayerJoined(
        uint playersId,
        string userName,
        address playersAddress,
        uint gamesPlayed,
        string dateJoined,
        uint tokensOwned,
        uint[] scores,
        string[] gameNames,
        uint highestScore
    );

    event GameEnded(
        uint PlayerId,
        address playersAddress,
        uint tokensEarned,
        uint Score
    );

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
}
