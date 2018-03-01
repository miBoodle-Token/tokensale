pragma solidity ^0.4.11;

//import './LunyrToken.sol';
// accepted from zeppelin-solidity https://github.com/OpenZeppelin/zeppelin-solidity
/*
 * ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
  uint public totalSupply;
  function balanceOf(address _who) public constant returns (uint);
  function allowance(address _owner, address _spender) public constant returns (uint);

  function transfer(address _to, uint _value) public returns (bool ok);
  function transferFrom(address _from, address _to, uint _value) public returns (bool ok);
  function approve(address _spender, uint _value) public returns (bool ok);
  event Transfer(address indexed from, address indexed to, uint value);
  event Approval(address indexed owner, address indexed spender, uint value);
}
/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
contract SafeMath {
  function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract OldToken is ERC20 {
    // flag to determine if address is for a real contract or not
    bool public isMiBoodleToken;
}

contract NewToken is ERC20, SafeMath {

    // flag to determine if address is for a real contract or not
    bool public isNewToken = false;
    address public owner;

    // Token information
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    bool public upgradeFinalized = false;

    // Upgrade information
    address public upgradeAgent;
    address bcdcReserveFund;

    function NewToken(address _upgradeAgent) public {
        isNewToken = true;
        if (_upgradeAgent == 0x0) revert();
        upgradeAgent = _upgradeAgent;
        owner = msg.sender;
    }

    // Upgrade-related methods
    function createToken(address _target, uint256 _amount) public {
        if (msg.sender != upgradeAgent) revert();
        if (_amount == 0) revert();
        if (upgradeFinalized) revert();

        balances[_target] = safeAdd(balances[_target], _amount);
        totalSupply = safeAdd(totalSupply, _amount);
        Transfer(_target, _target, _amount);
    }

    function finalizeUpgrade() external {
        if (msg.sender != upgradeAgent) revert();
        if (upgradeFinalized) revert();
        // this prevents createToken from being called after finalized
        upgradeFinalized = true;
    }

    // ERC20 interface: transfer _value new tokens from msg.sender to _to
    function transfer(address _to, uint256 _value) public returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] = safeSub(balances[msg.sender], _value);
            balances[_to] = safeAdd(balances[_to], _value);
            Transfer(msg.sender, _to, _value);
            return true;
        } else { return false; }
    }

    // ERC20 interface: transfer _value new tokens from _from to _to
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        //same as above. Replace this line with the following if you want to protect against wrapping uints.
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && safeAdd(balances[_to], _value) > balances[_to]) {
            balances[_to] = safeAdd(balances[_to], _value);
            balances[_from] = safeSub(balances[_from], _value);
            allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender], _value);
            Transfer(_from, _to, _value);
            return true;
        } else { return false; }
    }

    // ERC20 interface: delegate transfer rights of up to _value new tokens from
    // msg.sender to _spender
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    // ERC20 interface: returns the amount of new tokens belonging to _owner
    // that _spender can spend via transferFrom
    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    // ERC20 interface: returns the wmount of new tokens belonging to _owner
    function balanceOf(address _owner) public constant returns (uint256 balance) {
        return balances[_owner];
    }

    // Ownership related modifer and functions
    // @dev Throws if called by any account other than the owner
    modifier onlyOwner() {
      if (msg.sender != owner) {
        revert();
      }
      _;
    }

    /// @dev Fallback function throws to avoid accidentally losing money
    function() public payable { revert(); }
}

//Test the whole process against this: https://www.kingoftheether.com/contract-safety-checklist.html
contract UpgradeAgent is SafeMath {

    // flag to determine if address is for a real contract or not
    bool public isUpgradeAgent = false;

    // Contract information
    address public owner;

    // Upgrade information
    bool public upgradeHasBegun = false;
    bool public upgradeFinalized = false;
    OldToken public oldToken;
    NewToken public newToken;
    uint256 public originalSupply; // the original total supply of old tokens

    event NewTokenSet(address token);
    event UpgradeHasBegun();
    event InvariantCheck(uint oldTokenSupply, uint newTokenSupply, uint originalSupply, uint value);

    function UpgradeAgent(address _oldToken) public {
        if (_oldToken == 0x0) revert();
        owner = msg.sender;
        isUpgradeAgent = true;
        oldToken = OldToken(_oldToken);
        //if (!oldToken.isLunyrToken()) revert();
    }

    /// @notice Check to make sure that the current sum of old and
    /// new version tokens is still equal to the original number of old version
    /// tokens
    /// @param _value The number of LUN to upgrade
    function safetyInvariantCheck(uint256 _value) public {
        if (!newToken.isNewToken()) revert(); // Abort if new token contract has not been set
        uint oldSupply = oldToken.totalSupply();
        uint newSupply = newToken.totalSupply();
        InvariantCheck(oldSupply, newSupply, originalSupply, _value);
        if (safeAdd(oldSupply, newSupply) != safeSub(originalSupply, _value)) revert();
    }

    /// @notice Gets the original token supply in oldToken.
    /// Called by oldToken after reaching the success state
    function setOriginalSupply() external {
        originalSupply = oldToken.totalSupply();
    }

    /// @notice Sets the new token contract address
    /// @param _newToken The address of the new token contract
    function setNewToken(address _newToken) external {
        if (msg.sender != owner) revert();
        if (_newToken == 0x0) revert();
        if (upgradeHasBegun) revert(); // Cannot change token after upgrade has begun

        newToken = NewToken(_newToken);
        if (!newToken.isNewToken()) revert();
        NewTokenSet(newToken);
    }

    /// @notice Sets flag to prevent changing newToken after upgrade
    function setUpgradeHasBegun() internal {
      if (!upgradeHasBegun) {
        upgradeHasBegun = true;
        UpgradeHasBegun();
      }
    }

    /// @notice Creates new version tokens from the new token
    /// contract
    /// @param _from The address of the token upgrader
    /// @param _value The number of tokens to upgrade
    function upgradeFrom(address _from, uint256 _value) public {
        if (msg.sender != address(oldToken)) revert(); // only upgrade from oldToken
        if (!newToken.isNewToken()) revert(); // need a real newToken!
        if (upgradeFinalized) revert(); // can't upgrade after being finalized

        setUpgradeHasBegun();
        // Right here oldToken has already been updated, but corresponding
        // LUN have not been created in the newToken contract yet
        safetyInvariantCheck(_value);

        newToken.createToken(_from, _value);

        //Right here totalSupply invariant must hold
        safetyInvariantCheck(0);
    }

    function finalizeUpgrade() external {
        if (msg.sender != address(oldToken)) revert();
        if (upgradeFinalized) revert();

        safetyInvariantCheck(0);

        upgradeFinalized = true;

        newToken.finalizeUpgrade();
    }

    /// @dev Fallback function allows to deposit ether.
    function() public
        payable
    {
      revert();
    }

}
