// SPDX-License-Identifier: Unlicensed

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

pragma solidity ^0.8.0;

contract CryptoLotto is VRFConsumerBaseV2, AutomationCompatibleInterface {
    address payable owner;

    uint public ticketFee;
    uint public drawTime;
    uint ticketPrize;

    uint public ticketSold;

    uint public id;

    uint64 constant TEN_MINUTES = 600;

    bool upKeepState;
    bool upKeepWinners; 
    bool upKeepPayOut;

    address payable [] public buyers;

    mapping(uint => uint) public prizes;
    mapping(uint => address payable) public winners;

    enum State{
        Active,
        NonBuyable,
        Drawn,
        Expired
    }

    State public state;

    event TicketCreate(uint256 _ticketFee, uint256 _drawTime, uint256 _ticketPrize, State _state);
    event BuyTicket(uint256 _id, address buyer);
    event StateChange(State _state);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    uint256[] randomWords;

    uint64 s_subscriptionId;
    VRFCoordinatorV2Interface COORDINATOR;

    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    uint32 callbackGasLimit = 1500000;

    uint16 requestConfirmations = 3;

    uint32 numWords = 3;

    constructor(
        uint64 subscriptionId
    )
        VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
        s_subscriptionId = subscriptionId;
        owner = payable(msg.sender);
        state = State.Expired;
        ticketSold = buyers.length;
    }

    modifier _onlyOwner() {
        require(msg.sender == owner, "Authentication failure");
        _;
    }

    modifier _inState(State _state) {
        require(state == _state, "State not suitable");
        _;
    }

    modifier _afterTime(uint _time) {
        require(_time >= block.timestamp);
        _;
    }

    function checkUpkeep(
        bytes calldata /*checkData*/
        ) external view override returns (bool upkeepNeeded, bytes memory /*performData*/){
            if (block.timestamp > (drawTime - TEN_MINUTES) && block.timestamp < drawTime) {
                upkeepNeeded = upKeepState;
            }
            if (block.timestamp > drawTime) {
                upkeepNeeded = upKeepWinners;
            }
            if (block.timestamp > drawTime + TEN_MINUTES) {
                upkeepNeeded = upKeepPayOut;
            }
            return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /*performData*/) external override {
        if (block.timestamp > (drawTime - TEN_MINUTES) && block.timestamp < drawTime) {
            upKeepState = false;
            setState();
        }
        if (block.timestamp > drawTime) {
            upKeepWinners = false;
            pickWinners();
        }
        if (block.timestamp > drawTime + TEN_MINUTES) {
            upKeepPayOut = false;
            payOut();
        }
    }

    function setState() private {
        state = State.NonBuyable;
        emit StateChange(state);
    }

    function createTicket(uint _ticketFee, uint _drawTime) _onlyOwner() _inState(State.Expired)  external {
        ticketFee = _ticketFee;
        drawTime = _drawTime;
        ticketPrize = 60 * _ticketFee;
        uint counter = 4;
        for (uint i = 0; i < 3; i++) {
            prizes[i] = ticketPrize * counter / 10;
            counter -= 1;
        }
        id = uint(keccak256(abi.encodePacked(block.timestamp, drawTime))) % 10000;
        ticketSold = buyers.length;
        upKeepWinners = true;
        upKeepState = true;
        upKeepPayOut = true;
        state = State.Active;
        emit TicketCreate(_ticketFee, _drawTime, ticketPrize, state);
        emit StateChange(state);
    }

    function buyTicket() _inState(State.Active) public payable {
        require(msg.value >= ticketFee, "Insufficient amount");
        buyers.push(payable(msg.sender));
        ticketSold++;
        emit BuyTicket(id, msg.sender);
    }
 
    function pickWinners() public returns (uint256 requestId) {
        requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
    );
    }

    function payOut() public payable {
        for (uint i = 0; i < 3; i++) {
            winners[i].transfer(prizes[i]);
        }
        buyers = new address payable [](0);
        randomWords = new uint[](0);
        state = State.Expired;
        emit StateChange(state);
    }

    function _fullfillRandomness(uint[] memory _randomWords) public  {
        for (uint i = 0; i < 3; i++) {
            uint winnerIndex =  _randomWords[i] % buyers.length;
            winners[i] = buyers[winnerIndex];
            buyers[winnerIndex] = buyers[buyers.length - 1];
            buyers.pop();
        }
        state = State.Drawn;
        emit StateChange(state);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        randomWords = _randomWords;
        _fullfillRandomness(_randomWords);
        emit RequestFulfilled(_requestId, _randomWords);
    }

    receive() payable external{}

    function getBalance() _onlyOwner() public view returns(uint) {
        return address(this).balance;
    }

    function withdraw() _onlyOwner() /* _inState(State.Expired) */ public payable {
        owner.transfer(address(this).balance);
    }
}