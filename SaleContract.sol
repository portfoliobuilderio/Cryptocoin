pragma solidity 0.4.24;

import './Token.sol';

contract SaleContract{
  using SafeMath for uint256;
  
  uint256 constant internal TOKEN_DECIMALS = 10**5;
  uint256 constant internal TOKEN_SUPPLY = 1000000000*TOKEN_DECIMALS; //1,000,000,000.00000, 1 billion 5 decimals
  uint256 constant internal MIN_CONTRIBUTION = 0.01 ether; //$5 min
  uint256 constant internal ETH_DECIMALS = 10**18;
  uint16 constant internal TIERS = 10;

  uint256 public totalTokensSold;
  uint256 public weiEarned;
  address public holdings;
  address private owner;
  uint16 private tier;
  bool private paused;
  bool private activeMemebershipSale;

  //Token Smart Contract
  Token public tokenAddress;

  struct Participant{
    uint256 tokensTransferable;
    uint256 remainingWei;
  }

  mapping(address => Participant) public participants;

  struct SaleTier {      
    uint256 tokensToBeSold;  //amount of tokens to be sold in this SaleTier
    uint256 tokensSold;      //amount of tokens sold in each SaleTier
    uint256 price;           //how many wei per token
  }
   
  mapping(uint16 => SaleTier) public saleTier;

  event LogTokensPurchased(address indexed buyer, uint256 indexed qtyOfTokens);
  event LogOwnerWithdrawal(address ownerAddress, uint256 amountWithdrawn);
  event LogRefundWei(address tokenBuyer, uint256 amount);

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  modifier isValidPayload() {
    require(msg.data.length == 0 || msg.data.length == 4);
    _;
  }

  modifier saleIsActive() {
    require(activeMemebershipSale && totalTokensSold < TOKEN_SUPPLY);
    _;
  }

  modifier saleHasEnded() {
    require(totalTokensSold >= TOKEN_SUPPLY);
    _;
  }

  modifier activeContract(){
    require(paused == false);
    _;
  }

  // @dev confirm price thresholds and amounts
  // @param _holdings wallet address for holding ether
  // @param _token address of the token contract
  constructor(address _holdings, address _token) 
    public 
  {
    require(_holdings != address(0));
    require(_token != address(0));
    holdings = _holdings;
    paused = true;
    tokenAddress = Token(_token);    
    owner = msg.sender; 

    for(uint16 i=0; i<TIERS; i++){
      saleTier[i].tokensToBeSold = 100000000*TOKEN_DECIMALS;
      saleTier[i].price = 20000000000000+(20000000000000*i);//how many wei to get one token
    }//                   20000000000000
  }                    

  /// @dev Fallback function.
  /// @notice buyers send ETH to the saleContract address 
  function()
    public
    payable
  {
    if(msg.sender != owner){
        buyTokens();
    }
  }

  // @notice keeping owner private for the most part using a getter to see owner address
  function getOwner()
    view
    public
    returns(address _owner)
  {
    return owner;
  }

  // @dev owner needs to approve in token the transfer amount that the salecontract can transfer
  // @notice token only able to be traded by saleContract
  function startMembershipSale()
    external
    onlyOwner
  {
    tokenAddress.transferFrom(owner, address(this), 1000000000*TOKEN_DECIMALS);
    activeMemebershipSale = true;
    paused = false;
  }

  /// @notice called by fallback function
  function buyTokens()
    internal
    saleIsActive
    activeContract
    isValidPayload
    returns (bool success)
  {
    Participant storage participant = participants[msg.sender];
    SaleTier storage currentPrice = saleTier[tier];
    uint256 weiAmount = participant.remainingWei;
    participant.remainingWei = 0;
    uint256 remainingWei = msg.value.add(weiAmount);
    require(remainingWei >= MIN_CONTRIBUTION);
    uint256 price = currentPrice.price;
    uint256 totalTokensRequested;
    uint256 tierRemainingTokens;
    uint256 tknsRequested;
  
    while(remainingWei >= price && tier != TIERS) {
      SaleTier storage currentTier = saleTier[tier];
      price = currentTier.price;
      tknsRequested = remainingWei.div(price).mul(TOKEN_DECIMALS);
      tierRemainingTokens = currentTier.tokensToBeSold.sub(currentTier.tokensSold);
      if(tknsRequested >= tierRemainingTokens){
        tknsRequested -= tierRemainingTokens;
        currentTier.tokensSold += tierRemainingTokens;
        totalTokensRequested += tierRemainingTokens;
        remainingWei -= (tierRemainingTokens.mul(price).div(TOKEN_DECIMALS));
        tier++;
        
      } else{
        totalTokensRequested += tknsRequested;
        currentTier.tokensSold += tknsRequested;
        remainingWei -= (tknsRequested.mul(price).div(TOKEN_DECIMALS));
      }
    }
    
    uint256 amount = msg.value.sub(remainingWei);
    weiEarned += amount;
    totalTokensSold += totalTokensRequested;
    if(totalTokensSold == TOKEN_SUPPLY){activeMemebershipSale = false;}
    
    participant.remainingWei += remainingWei;
    emit LogTokensPurchased(msg.sender, totalTokensRequested);
    tokenAddress.transfer(msg.sender, totalTokensRequested);
    return true;
  }

  /// @notice to pause specific functions of the contract
  function pauseContract() 
    public 
    onlyOwner 
  {
    paused = true;
  }

  /// @notice used to unpause contract
  function unpauseContract() 
    public 
    onlyOwner 
  {
    paused = false;
  }

  // @notice owner withdraws ether periodically from the membership sale contract to holdings wallet
  function ownerWithdrawal(uint256 _amount) 
    public
    onlyOwner
    returns(bool success)
  {
    emit LogOwnerWithdrawal(msg.sender, _amount);
    holdings.transfer(_amount);
    return true; 
  }
  
  function contractBalance()
    view
    external
    onlyOwner
    returns (uint256)
  {
    return(address(this).balance);
  }


  // @notice no ethereum will be held in the membershipsale contract
  // when refunds become available the amount of Ethererum needed will
  // be manually transfered back to the membership sale to be refunded
  // @notice only the last person that buys tokens if they deposited enought to buy more 
  // tokens than what is available will be able to use this function
  function claimRemainingWei()
    external
    activeContract
    saleHasEnded
    returns (bool success)
  {
    Participant storage participant = participants[msg.sender];
    require(participant.remainingWei != 0);
    uint256 amount = participant.remainingWei;
    participant.remainingWei = 0;
    emit LogRefundWei(msg.sender, amount);
    msg.sender.transfer(amount);
    return true;
  }
}
