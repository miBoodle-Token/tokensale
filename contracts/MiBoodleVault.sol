pragma solidity ^0.4.18;

import "./MiBoodleToken.sol";

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

    // Set locktime for advertisers tokens
    // @param _time lock time for advertisers tokens
    function setUnlockAdvertisersTokensTime(uint256 _time) external onlyOwner {
        unlockAdvertisersTokensTime = safeAdd(now, _time);
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