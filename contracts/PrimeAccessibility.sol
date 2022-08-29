// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";

contract PrimeAccessibility {

    using Counters for Counters.Counter;
    Counters.Counter private _accountId;

    mapping(uint256 => address) public addressById;
    mapping(address => bool) public access;

    error Not_PrimeAccount();

    struct Account {
        uint256 accountId;
        address accountAddress;
    }
    Account[] public accounts;

    modifier onlyPrimeAccounts {
        if(access[msg.sender] == false) { revert Not_PrimeAccount(); }
        _;
    }

    function signUp() public {
        _accountId.increment();
        Account memory account = Account({
            accountId: _accountId.current(),
            accountAddress: msg.sender
        });
        accounts.push(account);

        addressById[_accountId.current()] = msg.sender;
        access[msg.sender] = true;
    }
}