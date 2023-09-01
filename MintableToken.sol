
// File: openzeppelin-contracts/contracts/utils/Context.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: openzeppelin-contracts/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: v1/MintableToken.sol


pragma solidity ^0.8.0;

contract MintableToken is Ownable {
    string public name;
    string public symbol;
    uint8 constant public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 immutable public maxSupply;
    mapping(address => bool) public isMinter;
    address public feeTo;
    uint256 public feeRate;
    uint256 constant public maxFeeRate = 500;
    mapping(address => bool) public isLP;
    address public liquidityProxy;
    uint256 public whaleThreshold;
    uint256 public minWhaleThreshold = 1;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint256 maxSupply_, address feeTo_, uint256 feeRate_, uint256 whaleThreshold_) {
        name = name_;
        symbol = symbol_;
        maxSupply = maxSupply_ * 1e18;
        _setFee(feeTo_, feeRate_);
        _setWhaleThreshold(whaleThreshold_);
    }

    function _setFee(address feeTo_, uint256 feeRate_) internal{
        require(feeRate_ <= maxFeeRate, "exceed max fee rate");
        feeTo = feeTo_;
        feeRate = feeRate_;
    }

    function _setWhaleThreshold(uint256 whaleThreshold_) internal {
        require(whaleThreshold_ >= minWhaleThreshold && whaleThreshold_ <= 10000, "invalid whale threshold");
        whaleThreshold = whaleThreshold_;
    }

    function setFee(address feeTo_, uint256 feeRate_) external onlyOwner{
        _setFee(feeTo_, feeRate_);
    }

    function setMinter(address account, bool status) external onlyOwner{
        isMinter[account] = status;
    }

    function setLiquidityProxy(address _liquidityProxy) external onlyOwner{
        liquidityProxy = _liquidityProxy;
    }

    function setLP(address addr, bool status) external onlyOwner{
        isLP[addr] = status;
    }

    function setWhaleThreshold(uint256 whaleThreshold_) external onlyOwner{
        _setWhaleThreshold(whaleThreshold_);
    }

    function mint(address to, uint256 amount) external{
        require(isMinter[msg.sender], "only minter");
        _mint(to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function maxTransferValue() public view returns(uint256){
        return whaleThreshold * totalSupply / 10000;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            balanceOf[from] = fromBalance - amount;
        }
        if(feeTo != address(0) && liquidityProxy != from && liquidityProxy != to && (isLP[from] || isLP[to])){
            require(amount <= maxTransferValue(), "exceed whale threshold");
            uint256 fee = feeRate * amount / 10000;
            if(fee > 0){
                balanceOf[feeTo] += fee;
                emit Transfer(from, feeTo, fee);
                amount -= fee;
            }
        }
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        totalSupply += amount;
        require(totalSupply <= maxSupply, "exceed max supply");
        unchecked {
            balanceOf[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}
