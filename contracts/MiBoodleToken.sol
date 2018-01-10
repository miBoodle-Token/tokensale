pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./ERC20.sol";
import "./UpgradeAgent.sol";

contract MiBoodleVault is Ownable,SafeMath {
  
  event Released(uint256 amount);

  // flag to determine if address is for a real contract or not
  bool public isMiBoodleVault = false;

  MiBoodleToken miBoodleToken;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;

  // address of our private MultiSigWallet contract
  address public miBoodleMultisig;

  // flag to determine all the token for advertisers already unlocked or not
  bool public unlockedAllTokensForAdvertisers = false;
  
  uint256 public unlockAdvertisersTokensTime;

  mapping (address => uint256) private balances;
  mapping (address => uint256) public released;

  /**
    * @param _unlockAdvertisersTokensTime Time for advertisers tokens unlock
    */
    function MiBoodleVault(uint256 _unlockAdvertisersTokensTime) public {
      owner = msg.sender;
      // Mark it as MiBoodleVault
      isMiBoodleVault = true;
      // Set advertisers tokens unlock time
      unlockAdvertisersTokensTime = safeAdd(now, _unlockAdvertisersTokensTime);
    }

    // Set miBoodleToken 
    // @param _miBoodleToken Address of miBoodleToken contract 
    function setMiBoodleToken(MiBoodleToken _miBoodleToken) external onlyOwner {
        require(_miBoodleToken != address(0));
        miBoodleToken = _miBoodleToken;
    }

    // Set miBoodleMultiSig 
    // @param _miBoodleMultiSig Address of miBoodleMultiSig contract
    function setMiBoodleMultiSigWallet(address _miBoodleMultisig) external onlyOwner {
        require(_miBoodleMultisig != address(0));
        miBoodleMultisig = _miBoodleMultisig;
    }

  /**
    * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
    * @param _duration duration in seconds of the period in which the tokens will vest
    */
    function setInitialData(uint256 _cliff, uint256 _duration) external onlyOwner {
      require(_cliff <= _duration);
      duration = _duration;
      cliff = safeAdd(now, _cliff);
      start = now;
    }

    // Transfer Advertisers-Buy-In Tokens To MultiSigWallet - 18 Months(549 Days) Locked
    function unlockForAdvertisers() external isSetMiBoodleToken isSetMiBoodleMultiSig {

        // If it has not reached 18 months mark do not transfer
        require(now > unlockAdvertisersTokensTime);

        // If it is already unlocked then do not allowed
        require(!unlockedAllTokensForAdvertisers);

        // Will fail if miBoodleVault token balance is not sufficient 
        require(miBoodleToken.balanceOf(this) >= 100000000 ether);

        // Mark it as unlocked
        unlockedAllTokensForAdvertisers = true;

        // transfer 100 million tokens to advertisers team
        require(miBoodleToken.transfer(miBoodleMultisig, 100000000 ether));
    }
   
  /**
    * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
    */
    function setBeneficiaryData(address _beneficiary, uint256 _totalTokensAssign) external onlyOwner {
      
      // Check beneficiary address is valid or not
      require(_beneficiary != address(0));
      
      // Check tokens to assign is vaild
      require(_totalTokensAssign != 0);
      balances[_beneficiary] = safeAdd(balances[_beneficiary], _totalTokensAssign);
    }

  /**
    * @param _value The number of miBoodle tokens to destroy of miBoodleVault
    */
    function burn(uint _value) public onlyOwner isSetMiBoodleToken {
      // Check tokens to destroy is valid
      require(_value != 0);
      // Check miBoodleVault token balance is valid 
      require(miBoodleToken.balanceOf(this) != 0);
      // Burn miBoodleTokens of miBoodleVault
      require(miBoodleToken.burn(_value));
    }

  /**
   * @notice Transfers vested tokens to beneficiary.
   */
  function release() public isSetMiBoodleToken {
    require(balances[msg.sender] != 0);
    require(miBoodleToken.balanceOf(this) != 0);
    
    uint256 unreleased = releasableAmount(msg.sender);

    require(unreleased != 0);

    balances[msg.sender] = safeSub(balances[msg.sender], unreleased);
    released[msg.sender] = safeAdd(released[msg.sender], unreleased);

    miBoodleToken.transfer(msg.sender, unreleased);

    Released(unreleased);
  }

  /**
   * @dev Calculates the amount that has already vested but hasn't been released yet.
   * @param _beneficiary Address of beneficiary which is being vested
   */
  function releasableAmount(address _beneficiary) public view returns (uint256) {
    // Counting total balance of beneficiary by adding current balance and released tokens balance
    uint256 totalBalance = safeAdd(balances[_beneficiary], released[_beneficiary]);
    uint256 availableBalance = safeDiv(safeMul(totalBalance, safeSub(cliff, start)), duration);
    uint256 releasableBalance = safeMul(availableBalance, safeDiv(vestedAmount(_beneficiary), availableBalance));
    return safeSub(releasableBalance, released[_beneficiary]);
  }

  /**
   * @dev Calculates the amount that has already vested.
   * @param _beneficiary Address of beneficiary which is being vested
   */
  function vestedAmount(address _beneficiary) public view returns (uint256) {
    uint256 currentBalance = balances[_beneficiary];
    uint256 totalBalance = safeAdd(currentBalance, released[_beneficiary]);

    if (now < cliff) {
      return 0;
    } else if (now >= safeAdd(start,duration)) {
      return totalBalance;
    } else {
      return safeDiv(safeMul(totalBalance,safeSub(now,start)),duration);
    }
  }

  /**
   * @dev Throws if miBoodleToken is not set.
   */
  modifier isSetMiBoodleToken() {
    // Fail if miBoodleToken is not set
    require(miBoodleToken != address(0));
    _;
  }

  /**
   * @dev Throws if miBoodleMultiSig is not set.
   */
   modifier isSetMiBoodleMultiSig() {
      // Fail if miBoodleMultiSig is not set
      require(miBoodleMultisig != address(0));
      _;
   }
}

contract MiBoodleToken is ERC20,Ownable,SafeMath {

    //flag to determine if address is for real contract or not
    bool public isMiBoodleToken = false;
    
    //Address of Crowdsale contract
    address public crowdSale;
    //Token related information
    string public constant NAME = "miBoodle";
    string public constant SYMBOL = "MIBO";
    uint256 public constant DECIMAL = 18; // decimal places

    //mapping of token balances
    mapping (address => uint256) balances;
    //mapping of allowed address for each address with tranfer limit
    mapping (address => mapping (address => uint256)) allowed;
    //mapping of allowed address for each address with burnable limit
    mapping (address => mapping (address => uint256)) allowedToBurn;

    address public upgradeMaster;
    UpgradeAgent public upgradeAgent;
    uint256 public totalUpgraded;
    bool public upgradeAgentStatus = false;

    //event
    event Burn(address owner,uint256 _value);
    event ApproveBurner(address owner, address canBurn, uint256 value);
    event BurnFrom(address _from,uint256 _value);
    event Upgrade(address indexed _from, address indexed _to, uint256 _value);
    event UpgradeAgentSet(address agent);

    //modifier for validate external call
    modifier onlyCrowdSale {
        require(msg.sender == crowdSale);
        _;
    }

    function MiBoodleToken(address _crowdSale) public {
        isMiBoodleToken = true;
        crowdSale = _crowdSale;
    }

    // @param _who The address of the investor to check balance
    // @return balance tokens of investor address
    function balanceOf(address _who) public constant returns (uint) {
        return balances[_who];
    }

    // @param _owner The address of the account owning tokens
    // @param _spender The address of the account able to transfer the tokens
    // @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) public constant returns (uint) {
        return allowed[_owner][_spender];
    }

    // @param _owner The address of the account owning tokens
    // @param _spender The address of the account able to transfer the tokens
    // @return Amount of remaining tokens allowed to spent
    function allowanceToBurn(address _owner, address _spender) public constant returns (uint) {
        return allowedToBurn[_owner][_spender];
    }

    //  Transfer `value` miBoodle tokens from sender's account
    // `msg.sender` to provided account address `to`.
    // @param _to The address of the recipient
    // @param _value The number of miBoodle tokens to transfer
    // @return Whether the transfer was successful or not
    function transfer(address _to, uint _value) public returns (bool ok) {
        //validate receiver address and value.Now allow 0 value
        require(_to != 0 && _value > 0);
        uint256 senderBalance = balances[msg.sender];
        //Check sender have enough balance
        require(senderBalance >= _value);
        senderBalance = safeSub(senderBalance, _value);
        balances[msg.sender] = senderBalance;
        balances[_to] = safeAdd(balances[_to],_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    //  Transfer `value` miBoodle tokens from sender 'from'
    // to provided account address `to`.
    // @param from The address of the sender
    // @param to The address of the recipient
    // @param value The number of miBoodle to transfer
    // @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint _value) public returns (bool ok) {
        //validate _from,_to address and _value(Now allow with 0)
        require(_from != 0 && _to != 0 && _value > 0);
        //Check amount is approved by the owner for spender to spent and owner have enough balances
        require(allowed[_from][msg.sender] >= _value && balances[_from] >= _value);
        balances[_from] = safeSub(balances[_from],_value);
        balances[_to] = safeAdd(balances[_to],_value);
        allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender],_value);
        Transfer(_from, _to, _value);
        return true;
    }

    //  `msg.sender` approves `spender` to spend `value` tokens
    // @param spender The address of the account able to transfer the tokens
    // @param value The amount of wei to be approved for transfer
    // @return Whether the approval was successful or not
    function approve(address _spender, uint _value) public returns (bool ok) {
        //validate _spender address
        require(_spender != 0);
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    //  `msg.sender` approves `_canBurn` to burn `value` tokens
    // @param _canBurn The address of the account able to burn the tokens
    // @param _value The amount of wei to be approved for burn
    // @return Whether the approval was successful or not
    function approveForBurn(address _canBurn, uint _value) public returns (bool ok) {
        //validate _spender address
        require(_canBurn != 0);
        allowedToBurn[msg.sender][_canBurn] = _value;
        ApproveBurner(msg.sender, _canBurn, _value);
        return true;
    }

    //  Burn `value` miBoodle tokens from sender's account
    // `msg.sender` to provided _value.
    // @param _value The number of miBoodle tokens to destroy
    // @return Whether the Burn was successful or not
    function burn(uint _value) public returns (bool ok) {
        //validate receiver address and value.Now allow 0 value
        require(_value > 0);
        uint256 senderBalance = balances[msg.sender];
        require(senderBalance >= _value);
        senderBalance = safeSub(senderBalance, _value);
        balances[msg.sender] = senderBalance;
        totalSupply = safeSub(totalSupply,_value);
        Burn(msg.sender, _value);
        return true;
    }

    //  Burn `value` miBoodle tokens from sender 'from'
    // to provided account address `to`.
    // @param from The address of the burner
    // @param to The address of the token holder from token to burn
    // @param value The number of miBoodle to burn
    // @return Whether the transfer was successful or not
    function burnFrom(address _from, uint _value) public returns (bool ok) {
        //validate _from,_to address and _value(Now allow with 0)
        require(_from != 0 && _value > 0);
        //Check amount is approved by the owner to burn and owner have enough balances
        require(allowedToBurn[_from][msg.sender] >= _value && balances[_from] >= _value);
        balances[_from] = safeSub(balances[_from],_value);
        totalSupply = safeSub(totalSupply,_value);
        allowedToBurn[_from][msg.sender] = safeSub(allowedToBurn[_from][msg.sender],_value);
        BurnFrom(_from, _value);
        return true;
    }

    //Set Crowdsale contract address
    function setCrowdSale(address _address) public onlyOwner {
        require(_address != 0);
        crowdSale = _address;
    }

    //Setter method for balances
    function setBalances(address _investor,uint256 _value) external onlyCrowdSale returns (bool) {
        require(_investor != 0 && _value > 0);
        require(crowdSale != 0);
        balances[_investor] = safeAdd(balances[_investor],_value);
        totalSupply = safeAdd(totalSupply,_value);
        return true;
    }

    // Token upgrade functionality

    /// @notice Upgrade tokens to the new token contract.
    /// @dev Required state: Success
    /// @param value The number of tokens to upgrade
    function upgrade(uint256 value) external {
        /*if (getState() != State.Success) throw; // Abort if not in Success state.*/
        require(upgradeAgentStatus && upgradeAgent.owner() != 0x0); // need a real upgradeAgent address

        // Validate input value.
        require (value > 0);
        require (value <= balances[msg.sender]);

        // update the balances here first before calling out (reentrancy)
        balances[msg.sender] = safeSub(balances[msg.sender], value);
        totalSupply = safeSub(totalSupply, value);
        totalUpgraded = safeAdd(totalUpgraded, value);
        upgradeAgent.upgradeFrom(msg.sender, value);
        Upgrade(msg.sender, upgradeAgent, value);
    }

    /// @notice Set address of upgrade target contract and enable upgrade
    /// process.
    /// @dev Required state: Success
    /// @param agent The address of the UpgradeAgent contract
    function setUpgradeAgent(address agent) external onlyOwner {
        require(agent != 0 && msg.sender != upgradeMaster);
        upgradeAgent = UpgradeAgent(agent);
        require (upgradeAgent.isUpgradeAgent());
        // this needs to be called in success condition to guarantee the invariant is true
        upgradeAgentStatus = true;
        upgradeAgent.setOriginalSupply();
        UpgradeAgentSet(upgradeAgent);
    }

    /// @notice Set address of upgrade target contract and enable upgrade
    /// process.
    /// @dev Required state: Success
    /// @param master The address that will manage upgrades, not the upgradeAgent contract address
    function setUpgradeMaster(address master) external {
        require (master != 0x0 && msg.sender != upgradeMaster);
        upgradeMaster = master;
    }
}