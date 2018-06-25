pragma solidity 0.4.24;

import 'zeppelin-solidity/contracts/token/ERC20/StandardToken.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Token is StandardToken, Ownable{
    
    string public constant symbol = "CRY";
    string public constant name = "Cryptocoin";
    uint8 public constant decimals = 5;

  constructor()
    public
    {
        totalSupply_ = 1000000000 * 10**5;
        balances[msg.sender] = totalSupply_;
        assert(balances[owner] == totalSupply_);                
    }
}





