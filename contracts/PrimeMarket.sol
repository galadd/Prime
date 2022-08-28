// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract PrimeMarket {
    uint256 marketCount;

    mapping(uint256 => bool) public isActive;
    mapping(uint256 => string) public nameById;
    mapping(uint256 => uint256) public unitPriceById;
    mapping(uint256 => Market) public marketById;

    event MarketList(uint256 id, string name, uint256 unitPrice);

    struct Market {
        uint256 id;
        string name;
    }

    Market[] public market;

    modifier active(uint256 _id) {
        require(isActive[_id] == true, "You can not trade this market until it's set to active");
        _;
    }

    function activateMarket(uint256 _id) public {
        isActive[_id] = true;
    }

    function disactivateMarket(uint256 _id) public {
        isActive[_id] = false;
    }

    function addMarket(string memory _name, uint256 _unitPrice)
        public 
        {
            require(bytes(_name).length > 0);
            marketCount++;

            Market memory m = Market({
                id: marketCount,
                name: _name
            });
            market.push(m);

            nameById[marketCount] = _name;
            unitPriceById[marketCount] = _unitPrice;            
            marketById[marketCount] = m;
            isActive[marketCount] = false;

            emit MarketList(marketCount, _name, _unitPrice);
        }

    function updateUnitPrice(uint256 _id, uint256 _newUnitPrice) public {
        unitPriceById[_id] = _newUnitPrice;
    } 

    function editMarket(
        uint256 _id, 
        string memory _newName, 
        uint256 _newUnitPrice
        ) public {
            Market memory m = Market({
                id: _id,
                name: _newName
            });
            market.push(m);

            nameById[_id] = _newName;
            unitPriceById[_id] = _newUnitPrice;           
            marketById[_id] = m;
            isActive[_id] = false;

            emit MarketList(_id, _newName, _newUnitPrice);
    }

    function getMarketCount() public view returns (uint256) {
        return marketCount;
    }

    function getNameById(uint256 _id) public view returns (string memory) {
        return nameById[_id];
    }

    function getLatestUnitPriceById(uint256 _id) public view returns (uint256) {
        return unitPriceById[_id];
    }

    function getMarketById(uint256 _id) public view returns (Market memory) {
        return marketById[_id];
    }

    function getMarket() 
        public 
        view 
        returns (
            uint256[] memory, 
            string[] memory
        )
        {
            uint256[] memory id = new uint256[](marketCount);
            string[] memory name = new string[](marketCount);
                 for (uint i = 0; i < marketCount; i++) {
                    Market storage m = market[i];
                    id[i] = m.id;
                    name[i] = m.name;
                }
            return (id, name);
        }
}