// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DaoToken {
    string public name;
    string public symbol;
    uint8 constant public decimals = 18;
    uint256 immutable public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 immutable public burnRate;
    address immutable public fund;
    address constant public blackHole = 0x000000000000000000000000000000000000dEaD;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint256 totalSupply_, address initAddr, uint256 burnRate_, address fund_) {
        require(initAddr != address(0) && fund_ != address(0), "zero address");
        require(burnRate_ <= 10000, "fee rate > 10000");
        name = name_;
        symbol = symbol_;
        totalSupply_ *= 1e18;
        totalSupply = totalSupply_;
        balanceOf[initAddr] = totalSupply_;
        emit Transfer(address(0), initAddr, totalSupply_);
        burnRate = burnRate_;
        fund = fund_;
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

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            balanceOf[from] = fromBalance - amount;
        }
        if(to != blackHole && to != fund && from != fund){
            uint256 burnAmount = burnRate * amount / 10000;
            if(burnAmount > 0){
                balanceOf[blackHole] += burnAmount;
                emit Transfer(from, blackHole, burnAmount);
                amount -= burnAmount;
            }
        }
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
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
