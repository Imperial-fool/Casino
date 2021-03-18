pragma solidity >=0.6.0 <0.8.0;


interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

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

interface IReceivesBogRand{
    function receiveRandomness(uint256 random) external;
}
interface IBogRandOracle{
    function requestRandomness() external;
    
    function getNextHash() external view returns(bytes32);
    function getPendingRequest()external view returns (address);
    function removePendingRequest(address,bytes32 nextHash)external;
    function provideRandomness(uint256 random, bytes32 nextHash)external;
    function seed(bytes32 hash) external;
}


contract Dicing {
    using SafeMath for uint256;
   address public owner;
   // The minimum bet a user has to make to participate in the game
   uint public minimumBet = 25*(10**17); // Equal to 0.1 ether
   uint public maximumBet = 105*(10**17);
   // Dev fee 1% 
   // 4% goes to bog marketing wallet
   uint public devfee;
   uint public marketfee;
   uint public totalPayout;
   
   
   
   
   // Array of player
   address public currentAddress = address(0);
   address[] public players;
   
    // Each number has an array of players. Associate each number with a bunch of players

   // The number that each player has bet for
   mapping(address => uint256) playerBetsHighLow;
   
   mapping(address => uint256) playerBetsAmount;
   
   mapping(address => uint256) winnerList;
   
   mapping(address => uint256) randomNumber;
   
   
    modifier OnlyOwner(){
        require(msg.sender == owner);
        _;
    }
    modifier OnlyWinner(){
        require(checkWinner(msg.sender) == true);
        _;
    }
	
	
	address public Marketingwallet = 0x075775b21Fc78FE9F12967715C360279d2Ee2472;
	address public RNGOracle = 0x3886F3f047ec3914E12b5732222603f7E962f5Eb;
	address public Bog = 0xD7B729ef857Aa773f47D37088A1181bB3fbF0099;

  	IBogRandOracle public Rngical;
  	
    constructor() {
      
        Rngical = IBogRandOracle(RNGOracle);
        IERC20(Bog).approve(address(RNGOracle), uint256(-1));
        IERC20(Bog).approve(owner,uint256(-1));
        IERC20(Bog).approve(Marketingwallet,uint256(-1));
        IERC20(Bog).approve(address(this),uint256(-1));
        owner = msg.sender;
    }
    
    function checkWinner(address player) public view returns(bool){
      if(winnerList[player] > 0)
         return true;
      else
         return false;
   }
   function checkPlayerExists(address player) public view returns(bool){
      if(playerBetsAmount[player] > 0)
         return true;
      else
         return false;
   }

   
	function bet(uint256 plusorminus, uint256 input) public {

      // Check that the amount paid is bigger or equal the minimum bet
      require(input >= minimumBet);
      require(currentAddress == address(0));  
      require(checkPlayerExists(msg.sender) == false);
      require(IERC20(Bog).balanceOf(msg.sender) > input);
      
      IERC20(Bog).transferFrom(msg.sender, address(this), input);
      
      playerBetsAmount[msg.sender] = (input*95)/100;
      
       // Set the number bet for that player
      playerBetsHighLow[msg.sender] = plusorminus;
     
      currentAddress = msg.sender;
      
      players.push(msg.sender);
      
      marketfee += (input*4)/100;
      devfee += (input/100);
      
      this.refreshNumber();
      
   }
	
    function receiveRandomness(uint256 random) external {
        require(msg.sender == address(Rngical)); // Ensure the sender is the oracle
        randomNumber[currentAddress] = (random %100) +1;
        checkwinner(currentAddress);
    }
    function refreshNumber() external{
        IBogRandOracle(Rngical).requestRandomness();
        
    }

	function distributePrizes() public OnlyWinner {
        uint winnerBogAmount = (winnerList[msg.sender]*2);

		

        IERC20(Bog).transfer(msg.sender, winnerBogAmount);

		totalPayout += winnerBogAmount;
		delete randomNumber[msg.sender];
	}
	
    function checkwinner(address player) public {
            if (randomNumber[player] > 0){
                if (playerBetsHighLow[player] == 1){
                    if (randomNumber[player] >= 55){
                        if (winnerList[player] > 0){
                            winnerList[player] += playerBetsAmount[player];
                        }else{
                            winnerList[player] = playerBetsAmount[player];
                        }
                    }
                    else{
                        devfee += playerBetsAmount[player]/4;
                        marketfee += playerBetsAmount[player]/4;
                    }
                    
                }
                if (playerBetsHighLow[player] == 0){
                    if (randomNumber[player] <= 45){
                        if (winnerList[player] > 0){
                            winnerList[player] += playerBetsAmount[player];
                        }else{
                            winnerList[player] = playerBetsAmount[player];
                        }
                    }else{
                        devfee += playerBetsAmount[player]/4;
                        marketfee += playerBetsAmount[player]/4;
                    }
                }
                
                delete playerBetsAmount[player];
                delete playerBetsHighLow[player];
            }
            currentAddress = address(0);
    }
    
    function checkwinnings(address x) public view returns (uint256){
        return winnerList[x]*2;
    }
    
    function checkrandom(address x) public view returns (uint256){
        return randomNumber[x];
    }
    
    function claimDevfee() public OnlyOwner{
        IERC20(Bog).approve(address(this), marketfee + devfee);
        IERC20(Bog).transferFrom(address(this), Marketingwallet , marketfee);
        IERC20(Bog).transferFrom(address(this), owner, devfee);
		marketfee = 0;
		devfee = 0;
    }
    function approve() public{
        IERC20(Bog).approve(address(this), uint(-1));
    }
}
