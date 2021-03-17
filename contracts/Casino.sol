pragma solidity >=0.6.0 <0.8.0;


import "./IERC20.sol";

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
}

interface IReceivesBogRand {
    function receiveRandomness(uint256 random) external;
}

interface IBogRandOracle {
    function requestRandomness() external;
    
    function getNextHash() external view returns (bytes32);
    function getPendingRequest() external view returns (address);
    function removePendingRequest(address adr, bytes32 nextHash) external;
    function provideRandomness(uint256 random, bytes32 nextHash) external;
    function seed(bytes32 hash) external;
}


contract First_Game is IReceivesBogRand{
   using SafeMath for uint256;
   
   	
   IBogRandOracle Rngical;
   
   address public owner;
   // The minimum bet a user has to make to participate in the game
   uint public minimumBet = 10000000; // Equal to 0.1 ether

   // The total amount of BNB bet for this current game
   uint public totalBet = 0;

   // The total number of bets the users have made
   uint public numberOfBets = 0;

   // The maximum amount of bets can be made for each game
   uint public maxAmountOfBets = 1;
   
   // The max amount of bets that cannot be exceeded to avoid excessive gas consumption
   // when distributing the prizes and restarting the game
   uint public constant LIMIT_AMOUNT_BETS = 100;
    
   // Dev fee 2% 
   // 3% goes to bog marketing wallet
   uint public devfee;
   uint public marketfee;
   
   uint256 public number;
   // Array of player

   address[] public players;

   // Each number has an array of players. Associate each number with a bunch of players
   mapping(uint => address[]) numberBetPlayers;

   // The number that each player has bet for
   mapping(address => uint) playerBetsNumber;

   // Modifier to only allow the execution of functions when the bets are completed
    modifier OnlyWhenMax(){
        require(numberOfBets >= maxAmountOfBets);
        _;
    }
    modifier OnlyOwner(){
        require(msg.sender == owner);
        _;
    }
	


    constructor(){
        Rngical = IBogRandOracle(0x3886F3f047ec3914E12b5732222603f7E962f5Eb);
        IERC20(0xD7B729ef857Aa773f47D37088A1181bB3fbF0099).approve(address(0x3886F3f047ec3914E12b5732222603f7E962f5Eb), uint256(-1));
        owner = msg.sender;
    }

	function SetNewValues(uint newMaxAmountOfBets, uint newMinimumBet) public OnlyOwner{ //note to self: only stress tested to 100 wallets beware of increasing
	    maxAmountOfBets = newMaxAmountOfBets;
	    minimumBet = newMinimumBet;
	}

    function receiveRandomness(uint256 random) external override {
        require(msg.sender == address(Rngical)); // Ensure the sender is the oracle
        number = random;

    }
    function refreshNumber() external OnlyWhenMax{
        IBogRandOracle(Rngical).requestRandomness();
    }
    
	function checkPlayerExists(address player) public view returns(bool){
      if(playerBetsNumber[player] > 0)
         return true;
      else
         return false;
   }
   
	function bet(uint numberToBet) public payable{
      // Check that the max amount of bets hasn't been met yet
      assert(numberOfBets < maxAmountOfBets);

      // Check that the player doesn't exists
      assert(checkPlayerExists(msg.sender) == false);

      // Check that the number to bet is within the range
      assert(numberToBet >= 1 && numberToBet <= 10);

      // Check that the amount paid is bigger or equal the minimum bet
      assert(msg.value >= minimumBet);

      // Set the number bet for that player
      playerBetsNumber[msg.sender] = numberToBet;

      // The player msg.sender has bet for that number
      numberBetPlayers[numberToBet].push(msg.sender);
      
      totalBet += msg.value;
      devfee += (msg.value*2)/100;
      marketfee += (msg.value*3)/100;
      numberOfBets += 1;
      
	  
      if(numberOfBets >= maxAmountOfBets){
          this.refreshNumber();
      }
      if (number != 0){
          distributePrizes();
      }
   }
	
	

	function distributePrizes() public OnlyWhenMax{
		uint256 numberWinner;
		numberWinner = (number%10) +1;
		uint256 winnerAmount = totalBet / numberBetPlayers[numberWinner].length;
		

		
	 for(uint i = 0; i < numberBetPlayers[numberWinner].length ; i++){
            numberBetPlayers[numberWinner][i].call{value:winnerAmount}("");
      }
     if (numberBetPlayers[numberWinner].length == 0){
         numberOfBets = 0;
     }
     if (numberBetPlayers[numberWinner].length > 0){
        totalBet = 0;
        numberOfBets = 0;
     }
     for(uint j = 1; j <= 10; j++){
         delete numberBetPlayers[j];
      }
      number = 0;
      
	  
        
	}
	function claimdevandmarketfee()public OnlyOwner{
	    owner.call{value:devfee}("");
		address(0x075775b21Fc78FE9F12967715C360279d2Ee2472).call{value:marketfee}("");
	}
	
    function getNumberPicked(address x) public view returns(uint){
        return uint(playerBetsNumber[x]);
    }
    receive() payable external {}
}