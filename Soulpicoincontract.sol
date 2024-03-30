// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SoulPiToken is IERC20, Ownable {
    using SafeMath for uint256;

    string private _name = "SoulPi";
    string private _symbol = "SOULpi";
    uint8 private _decimals = 18;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    uint256 private constant _totalSupply = 1000000000 * 10**18; // Total supply of 1 billion tokens
    
    // Liquidity pool address where transfer tax will be deposited
    address private _liquidityPoolAddress;
    
    // Reflection tax rate in percentage (2%)
    uint256 private constant _reflectionTaxRate = 2;
    
    constructor(address liquidityPoolAddress) {
        require(liquidityPoolAddress != address(0), "Invalid liquidity pool address");
        _liquidityPoolAddress = liquidityPoolAddress;
        
        // Mint total supply to contract deployer
        _balances[msg.sender] = _totalSupply;
        
        // Send marketing funds to specified address
        uint256 marketingFundsAmount = 10000000 * 10**18; // 10 million tokens
        require(marketingFundsAmount <= _totalSupply, "Marketing funds exceed total supply");
        
        _balances[0xb3Dd5Cdb7F73acD1177c96409412e0b326E9C457] = marketingFundsAmount;
        emit Transfer(address(0), 0xb3Dd5Cdb7F73acD1177c96409412e0b326E9C457, marketingFundsAmount);
        
        // Airdrop 15% of total supply across 5000 random wallet addresses
        uint256 airdropAmount = _totalSupply.mul(15).div(100); // 15% of total supply
        uint256 airdropPerAddress = airdropAmount.div(5000); // Amount to be airdropped per address
        
        for (uint256 i = 1; i <= 5000; i++) {
            address randomAddress = address(uint160(uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, i)))));
            _balances[randomAddress] = _balances[randomAddress].add(airdropPerAddress);
            emit Transfer(address(0), randomAddress, airdropPerAddress);
        }
        
        revokeMintAuthority();
        revokeFreezeAuthority();
    }
    
    function name() public view override returns (string memory) {
        return _name;
    }
    
    function symbol() public view override returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        
        unchecked {
            _approve(sender, msg.sender, currentAllowance - amount);
        }
        
        return true;
    }
    
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

   function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        
        uint256 reflectionTaxAmount = amount.mul(_reflectionTaxRate).div(100);
        uint256 liquidityPoolTaxAmount = amount.mul(2).div(100); // 2% transfer tax
        
        uint256 transferAmount = amount.sub(reflectionTaxAmount).sub(liquidityPoolTaxAmount);
        
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(transferAmount);
        
        // Apply reflection tax
        if (reflectionTaxAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(reflectionTaxAmount);
            emit Transfer(sender, address(this), reflectionTaxAmount);
        }
        
        // Deposit liquidity pool tax
        if (liquidityPoolTaxAmount > 0) {
            _balances[_liquidityPoolAddress] = _balances[_liquidityPoolAddress].add(liquidityPoolTaxAmount);
            emit Transfer(sender, _liquidityPoolAddress, liquidityPoolTaxAmount);
        }
        
        emit Transfer(sender, recipient, transferAmount);
    }
    
    function revokeMintAuthority() private onlyOwner {
        // Revoke mint authority by transferring ownership to the zero address
        transferOwnership(address(0));
    }
    
    function revokeFreezeAuthority() private onlyOwner {
         // Revoke freeze authority by renouncing ownership
         renounceOwnership();
    }
}