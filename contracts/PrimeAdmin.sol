// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract PrimeAdmin {

    address constant DEV = 0xa3D8B95670974b230EcF8f82F00e9F9D1B4069B9;
    address primeAddress;
    address[] stakeholders;

    uint256 topicCount;

    mapping(address => bool) public stakeholderCheck;
    mapping(uint256 => string) public titleById;
    mapping(uint256 => uint256) public voteCountById;
    mapping(uint256 => mapping(address => bool)) public topicVoteCheck;

    error Not_PrimeAdminAddress();
    error Not_PrimeStakeholder();
    error HasAlreadyVoted();

    struct Topic {
        uint256 id;
        string title;
    }
    Topic[] private topics;

    modifier primeAdmin {
        if(msg.sender != primeAddress) { revert Not_PrimeAdminAddress(); }
        _;
    }

    modifier stakeholder {
        if(stakeholderCheck[msg.sender] == false) { revert Not_PrimeStakeholder(); }
        _;
    }

    function setPrimeAddress(address _primeAddress) public {
        primeAddress = _primeAddress;
    }

    function addStakeholders(address[] memory _stakeholders) public {
        require(msg.sender == DEV);
        stakeholders = _stakeholders;
        stakeholderCheck[msg.sender] = true;
    }

    function voteTopic(uint256 _id) public stakeholder {
        if(topicVoteCheck[_id][msg.sender] == true) { revert HasAlreadyVoted(); }
        uint256 _voteCount;
        _voteCount++;
        voteCountById[_id] = _voteCount;
        topicVoteCheck[_id][msg.sender] = true;
    }

    function addTopic(string memory _title) public {
        topicCount++;
        Topic memory topic = Topic({
            id: topicCount,
            title: _title
        });
        topics.push(topic);
        titleById[topicCount] = _title;
    }
}
