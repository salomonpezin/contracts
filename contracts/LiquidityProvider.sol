pragma solidity ^0.4.23;


import "./shared/AddressTools.sol";
import "./shared/SafeMath.sol";
import "./shared/Owned.sol";

import "./Scrinium.sol";
import "./Platform.sol";


contract LiquidityProvider is Owned {
    using AddressTools for address;
    using SafeMath for uint256;

    address public subscriptionsAddress;
    address public scriniumAddress;
    address public balancesAddress;
    address public platformAddress;

    address public commissionsAddress;
    mapping (uint => uint) public commissions;

    modifier onlyPlatform () {
        require(msg.sender == platformAddress);
        _;
    }

    modifier notZeroAddr (address _address) {
        require(_address.isContract());
        _;
    }

    event BalancesAddressSetted(address indexed _owner, address indexed _balancesAddress);
    event PlatformAddressSetted(address indexed _owner, address indexed _platformAddress);
    event CommissionsAddressSetted(address indexed _owner, address indexed _commissionsAddress);
    event CommissionTaken(
        address indexed _investor,
        uint indexed _tradeId,
        uint _amount
    );

    constructor (
        address _scriniumAddress,
        address _balancesAddress,
        address _commissionsAddress
    ) public {
        require(_scriniumAddress.isContract());
        require(_balancesAddress.isContract());
        require(_commissionsAddress != address(0));

        scriniumAddress = _scriniumAddress;
        balancesAddress = _balancesAddress;
        commissionsAddress = _commissionsAddress;

        emit BalancesAddressSetted(msg.sender, _balancesAddress);
        emit CommissionsAddressSetted(msg.sender, _commissionsAddress);
    }

    function setBalancesAddress(address _balancesAddress) external onlyOwner notZeroAddr(_balancesAddress) {
        this.removeBalancesTransferAllowance();
        balancesAddress = _balancesAddress;
        this.addBalancesTransferAllowance();
        emit BalancesAddressSetted(msg.sender, _balancesAddress);
    }

    function setPlatformAddress(address _platformAddress) external onlyOwner notZeroAddr(_platformAddress) {
        require(_platformAddress != address(0));
        platformAddress = _platformAddress;
        emit PlatformAddressSetted(msg.sender, _platformAddress);
    }

    function setCommissionsAddress(address _commissionsAddress) external onlyOwner {
        require(_commissionsAddress != address(0));
        commissionsAddress = _commissionsAddress;
        emit CommissionsAddressSetted(msg.sender, _commissionsAddress);
    }

    function addBalancesTransferAllowance() external onlyOwnerOrThis {
        Scrinium(scriniumAddress).approve(balancesAddress, 2 ** 256 - 1);
    }

    function removeBalancesTransferAllowance() external onlyOwnerOrThis {
        Scrinium(scriniumAddress).approve(balancesAddress, 0);
    }

    function withdrawPool(address _target, uint256 _value) external onlyOwner returns (bool) {
        Scrinium _scrinium = Scrinium(scriniumAddress);

        uint256 balance = _scrinium.balanceOf(address(this));

        uint256 _amount = (_value == 0 || _value > balance) ? balance : _value;
        address _to = (_target != address(0)) ? _target : owner;

        return _scrinium.transfer(_to, _amount);
    }

    function openTrade (
        uint _tradeId,
        address _investor,
        uint _masterTraderId,

        uint _instrumentId,
        uint _marginPercent,
        uint _leverage,
        uint _cmd,

        uint _openTime,
        uint _openPriceInstrument,
        uint _openPriceSCRBase,

        uint _commission
    ) external onlyOwner {
        // TODO: Make a more strict checking of the balance
        require(Scrinium(scriniumAddress).balanceOf(address(this)) > 0);

        Platform _platform = Platform(platformAddress);

        commissions[_tradeId] = _commission;

        _platform.openTrade(
            _tradeId,
            _investor,
            _masterTraderId,

            _instrumentId,
            _marginPercent,
            _leverage,
            _cmd,

            _openTime,
            _openPriceInstrument,
            _openPriceSCRBase
        );
    }

    function closeTrade (
        uint _tradeId,
        uint _marginRegulator,

        uint _closeTime,
        uint _closePriceInstrument,
        uint _closePriceSCRBase,

        uint _commission
    ) external onlyOwner returns (bool) {
        return _closeTrade(
            _tradeId,
            _marginRegulator,
            _closeTime,
            _closePriceInstrument,
            _closePriceSCRBase,
            _commission
        );
    }

    /**
    * It accepts only investorActualTrades
     */
    function closeAllTrades (
        uint[] _tradesIds,
        uint[] _marginRegulators,

        uint _closeTime,
        uint[] _closePriceInstruments,
        uint _closePriceSCRBase,

        uint[] _commissions
    ) external onlyOwner returns (bool) {
        for (uint i = 0; i < _tradesIds.length; i++) {
            _closeTrade(
                _tradesIds[i],
                _marginRegulators[i],
                _closeTime,
                _closePriceInstruments[i],
                _closePriceSCRBase,
                _commissions[i]
            );
        }

        return true;
    }

    function _takeCommission (
        address _investor,
        uint _tradeId
    ) private returns (bool) {
        require(Platform(platformAddress).takeCommission(
            _investor,
            _tradeId,
            commissionsAddress,
            commissions[_tradeId]
        ));

        emit CommissionTaken(
            _investor,
            _tradeId,
            commissions[_tradeId]
        );

        return true;
    }

    function _closeTrade (
        uint _tradeId,
        uint _marginRegulator,

        uint _closeTime,
        uint _closePriceInstrument,
        uint _closePriceSCRBase,

        uint _commission
    ) private returns (bool) {
        // TODO: Make a more strict checking of the balance of LiquidityProvider
        require(Scrinium(scriniumAddress).balanceOf(address(this)) > 0);

        Platform _platform = Platform(platformAddress);

        address _investor;
        (, _investor,,,,,,,,,) = _platform.getTrade(_tradeId);

        commissions[_tradeId] = commissions[_tradeId].add(_commission);

        require(_takeCommission(_investor, _tradeId));

        require(_platform.closeTrade(
            _tradeId,
            _marginRegulator,

            _closeTime,
            _closePriceInstrument,
            _closePriceSCRBase
        ));

        return true;
    }
}
