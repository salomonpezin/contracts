pragma solidity ^0.4.23;


import "./shared/AddressTools.sol";
import "./shared/SafeMath.sol";
import "./shared/Owned.sol";

import "./Scrinium.sol";
import "./LiquidityProvider.sol";


contract Balances is Owned {
    using AddressTools for address;
    using SafeMath for uint256;

    address public scriniumAddress;
    address public liquidityProviderAddress;
    address public platformAddress;

    mapping (address => uint256) balance;

    modifier onlyPlatform {
        require(msg.sender == platformAddress);
        _;
    }

    modifier notZeroAddr (address _address) {
        require(_address.isContract());
        _;
    }

    event PlatformAddressSetted(address indexed _owner, address indexed _platformAddress);
    event LiquidityProviderAddressSetted(address indexed _owner, address indexed _liquidityProviderAddress);

    event BalanceDeposited(address indexed _investor, uint _amount);
    event BalanceWithdrawed(address indexed _investor, uint _amount);
    event BalanceUpdated(address indexed _investor, int _amount);

    constructor(address _scriniumAddress) public {
        require(_scriniumAddress.isContract());
        scriniumAddress = _scriniumAddress;
    }

    function setPlatformAddress(address _platformAddress) external onlyOwner notZeroAddr(_platformAddress) {
        platformAddress = _platformAddress;
        emit PlatformAddressSetted(msg.sender, _platformAddress);
    }

    function setLiquidityProviderAddress(address _liquidityProviderAddress) external onlyOwner notZeroAddr(_liquidityProviderAddress) {
        liquidityProviderAddress = _liquidityProviderAddress;
        emit LiquidityProviderAddressSetted(msg.sender, _liquidityProviderAddress);
    }

    function deposit(uint _amount) external {
        Scrinium _scrinium = Scrinium(scriniumAddress);
        require(_scrinium.transferFrom(msg.sender, address(this), _amount));

        balance[msg.sender] = balance[msg.sender].add(_amount);

        emit BalanceDeposited(msg.sender, _amount);
    }

    function updateBalance(
        address _investor,
        int256 _amount
    ) external onlyPlatform {
        if (_amount != 0) {
            Scrinium _scrinium = Scrinium(scriniumAddress);
            // LiquidityProvider _lp = LiquidityProvider(liquidityProviderAddress);

            // TODO: Update balances according to LiquidityProvider contract
            //
            // 1. amount > 0:
            //    - Subtract amount from LiquidityProvider
            //    - Add amount to Balances
            //    - Add amount to investor
            //
            // 2. amount < 0:
            //    - Subtract amount from investor
            //    - Subtract amount from Balances
            //    - Add amount to LiquidityProver
            uint256 amount;

            if (_amount > 0) {
                amount = uint256(_amount);
                // ? FIXME: balance[liquidityProviderAddress] = balance[liquidityProviderAddress].sub(amount);
                require(_scrinium.transferFrom(liquidityProviderAddress, address(this), amount));
                balance[_investor] = balance[_investor].add(amount);
            } else {
                amount = uint256(-1 * _amount);
                require(_scrinium.transfer(liquidityProviderAddress, amount));
                balance[_investor] = balance[_investor].sub(amount);
                // ? FIXME: balance[liquidityProviderAddress] = balance[liquidityProviderAddress].add(amount);
            }
        }

        emit BalanceUpdated(_investor, _amount);
    }

    function withdrawal(uint _amount) external {
        require(balance[msg.sender] >= _amount);

        Scrinium _scrinium = Scrinium(scriniumAddress);
        require(_scrinium.transfer(msg.sender, _amount));


        balance[msg.sender] = balance[msg.sender].sub(_amount);

        emit BalanceWithdrawed(msg.sender, _amount);
    }

    function balanceOf(address _investor) public view returns(uint256) {
        return balance[_investor];
    }
}
