pragma solidity ^0.4.18;

import './Ownable.sol';
import './Haltable.sol';
import './SafeMath.sol';
import './MiBoodleToken.sol';

contract CrowdSale is Haltable,SafeMath {

    //crowdsale start time
    uint256 public start;
    //crowdsale end time
    uint256 public end;
    //Tokens per Ether in preFunding
    uint256 public preFundingtokens;
    //Tokens per Ether in Funding
    uint256 public fundingTokens;    
    //Token balance of Investor
    mapping (address => uint256) public balances;
    //total supply of tokens
    uint256 public totalSupply = 0;
    //token sale max
    uint256 public maxTokenSupply = 200000000 ether;
    //address of main token contract
    address public miBoodleToken;
    //address of multisig
    address public multisig;
    //address of vault
    address public vault;
    //Reference for MiBoodle Standard Tokens
    MiBoodleToken miBoodle;
    //Is crowdsale finalized
    bool public isCrowdSaleFinalized = false;
    
    //events
    event Allocate(address _investor,uint256 _tokens);
    event Claim(address _claimer);

    // Constructor function sets following
    // @param _wallet address where funds are collected
    // @param _preFundingtokens Tokens per Ether in preFunding
    // @param _fundingTokens Tokens per Ether in Funding
    // @param _start start time of crowdsale
    // @param _end end time of crowdsale
    function CrowdSale(uint256 _preFundingtokens,uint256 _fundingTokens,uint256 _start,uint256 _end) public {
        preFundingtokens = _preFundingtokens;
        fundingTokens = _fundingTokens;
        start = _start;
        end = _end;
    }
    
    //'owner' can set number of tokens per Ether in pre funding
    // @param _preFundingtokens Tokens per Ether in preFunding
    function setPreFundingtokens(uint256 _preFundingtokens) public stopIfHalted onlyOwner {
        preFundingtokens = _preFundingtokens;
    }

    //'owner' can set number of tokens per Ether in funding
    // @param _fundingTokens Tokens per Ether preFunding
    function setFundingtokens(uint256 _fundingTokens) public stopIfHalted onlyOwner {
        fundingTokens = _fundingTokens;
    }

    //owner can call to allocate tokens to investor who invested in other currencies
    //@ param _investor address of investor
    //@ param _tokens number of tokens to give to investor
    function cashInvestment(address _investor,uint256 _tokens) onlyOwner stopIfHalted external {
        //not allow if crowdsale ends.
        require(now < end);
        //validate address
        require(_investor != 0);
        //not allow with tokens 0
        require(_tokens > 0);
        //Call internal method to assign tokens
        assignTokens(_investor,_tokens);
    }

    // transfer the tokens to investor's address
    // Common function code for cashInvestment and Crowdsale Investor
    function assignTokens(address _investor, uint256 _tokens) internal {
        // Creating tokens and  increasing the totalSupply
        totalSupply = safeAdd(totalSupply,_tokens);
        // Assign new tokens to the sender
        balances[_investor] = safeAdd(balances[_investor],_tokens);
        // Finally token created for sender, log the creation event
        Allocate(_investor, _tokens);
    }

    //Owner can Set token contract
    //@ param _miBoodleToken address of token contract.
    function setMiBoodleToken(address _miBoodleToken) onlyOwner public {
        require(_miBoodleToken != 0);
        miBoodleToken = _miBoodleToken;
    }

    //Owner can Set Multisig wallet
    //@ param _multisig address of Multisig wallet.
    function setMultisigWallet(address _multisig) onlyOwner public {
        require(_multisig != 0);
        multisig = _multisig;
    }

    //Owner can Set TokenVault
    //@ param _vault address of TokenVault.
    function setMiBoodleTokenVault(address _vault) onlyOwner public {
        require(_vault != 0);
        vault = _vault;
    }

    //As all tokens distributed after completion of token sale investors has to claim tokens.
    function claimToken() stopIfHalted external {
        require(miBoodleToken != 0 && balances[msg.sender] >= 0 && now > end);
        miBoodle = MiBoodleToken(miBoodleToken);
        require(miBoodle.setBalances(msg.sender,balances[msg.sender]));
        totalSupply = safeSub(totalSupply,balances[msg.sender]);
        balances[msg.sender] = 0;
        Claim(msg.sender);
    }

    //Finalize crowdsale and allocate tokens to multisig and vault
    function finalizeCrowdSale() onlyOwner external {
        require(!isCrowdSaleFinalized);
        require(miBoodleToken != 0 && multisig != 0 && vault != 0 && now > end);
        miBoodle = MiBoodleToken(miBoodleToken);
        require(miBoodle.setBalances(multisig,250000000 ether));
        Claim(multisig);
        require(miBoodle.setBalances(vault,150000000 ether));
        isCrowdSaleFinalized = true;
        require(multisig.send(this.balance));
        Claim(vault);
    }

    //fallback function to accept ethers
    function() payable stopIfHalted external {
        //not allow if crowdsale ends.
        require(now <= end);
        //not allow to invest with 0 value
        require(msg.value > 0);
        //Hold created tokens for current state of funding
        uint256 createdTokens;
        if (now < start)
            createdTokens = safeMul(msg.value,preFundingtokens);
        else if (now >= start)
            createdTokens = safeMul(msg.value,fundingTokens);
        else
            revert();
        //total supply should not greater than maximum token to supply 
        require(safeAdd(createdTokens,totalSupply) <= maxTokenSupply);
        //call internal method to assign tokens
        assignTokens(msg.sender,createdTokens);
    }
}