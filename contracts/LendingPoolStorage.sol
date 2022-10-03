pragma solidity ^0.8.0;

import {UserConfiguration} from "./libraries/configuration/UserConfiguration.sol";
import {ReserveConfiguration} from "./libraries/configuration/ReserveConfiguration.sol";
import {ReserveLogic} from "./libraries/logic/ReserveLogic.sol";
import {DataTypes} from "./libraries/types/DataTypes.sol";

contract LendingPoolStorage {
    using ReserveLogic for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;

    mapping(address => DataTypes.ReserveData) internal _reserves;
    mapping(address => DataTypes.UserConfigurationMap) internal _usersConfig;

    // the list of the available reserves, structured as a mapping for gas savings reasons
    mapping(uint256 => address) internal _reservesList;

    uint256 internal _reservesCount;

    bool internal _paused;

    address _lendingPoolConfigurator;

    address _priceOracle;

    mapping(address => bool) public _isBridge;
    // bridge => token => totalUnbacked
    mapping(address => mapping(address => uint256)) public _totalUnbacked;
    // bridge => token => numberInlist =>debtInfor
    mapping(address => mapping(address => mapping(uint256 => DataTypes.UnBackedInfor)))
        public _bridgeUnbacked;
    // bridge => last debt number
    mapping(address => uint256) public _lastDebtNumber;
    // bridge => token => numberInlist => is backed ?
    mapping(address => mapping(address => mapping(uint256 => bool)))
        public _isBacked;
}
