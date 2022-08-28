// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";

import "./PrimeX.sol";
import "./PrimeMarket.sol";

contract PrimeTrade is PrimeMarket {

    PrimeX public primex;

    using Counters for Counters.Counter;
    Counters.Counter private _orderId;

    mapping(uint256 => Order) public orderById;
    mapping(uint256 => address) public orderIdByAddress;
    mapping(uint256 => uint256) public pnlByOrderId;
    mapping(uint256 => mapping(address => bool)) public marketStatusForSender;
    mapping(uint256 => mapping(address => uint256)) public costBySenderAndMarketId;
    mapping(uint256 => mapping(address => uint256)) public leverageBySenderAndMarketId;
    mapping(uint256 => mapping(address => Position)) public positionBySenderAndMarketId;
    mapping(uint256 => mapping(address => uint256)) public pnlBySenderAndMarketId;

    event OrderCreated(
        uint256 orderId, 
        address sender, 
        uint256 marketId, 
        Position position,
        uint256 leverage,
        uint256 amount
    );
    event TradeClosed(uint256 orderId, address sender, uint256 marketId, uint256 pnl);

    error MarketUntradeable();
    error LeverageLimit();

    constructor(address _primeXAddress) {
        primex = PrimeX(_primeXAddress);
    }

    enum Position {NIL, LONG, SHORT} // NIL = 0, LONG = 1, SHORT = 2. Default value is NIL
    enum ProfitOrLoss {NIL, PROFIT, LOSS} // NIL = 0, PROFIT = 1, LOSS = 2. Default value is NIL

    struct Order {
        uint256 orderId;
        address sender;
        uint256 marketId;
        Position position;
        uint256 leverage;
        uint256 amount;
    }

    struct PositionSize {
        uint256 marketId;
        address user;
        uint256 initialTotal;
        uint256 finalTotal;
        uint256 pnl;
        ProfitOrLoss profitOrLoss; 
    }

    Order[] public orders;
    PositionSize[] public positionSizes;

    function placeOrder(uint256 _marketId, Position _position, uint256 _leverage, uint256 _amount) 
        public
        payable
        returns (uint256, uint256)
        {   
            if(isActive[_marketId] == false) { revert MarketUntradeable(); } 
            if(_leverage > 10) { revert LeverageLimit(); }
            require(_amount > 0 && _amount == msg.value, "Amount to be traded must be greater than 0 and equal to msg.value");
            _orderId.increment();
            uint256 cost = getCostFromMarketIdAndAddress(_marketId, msg.sender) + _amount;
            uint256 oldSize = getCostFromMarketIdAndAddress(_marketId, msg.sender) * getLeveregeFromMarketIdAndAddress(_marketId, msg.sender);
            uint256 newSize = _amount * _leverage;
            uint256 positionSize;
            uint256 averageLeverage;

            // line 78-93 is processed when market is not already being traded by the sender
            if(marketStatusForSender[_marketId][msg.sender] == false) {
                Order memory order = Order({
                    orderId: _orderId.current(),
                    sender: msg.sender,
                    marketId: _marketId,
                    position: _position,
                    leverage: _leverage,
                    amount: _amount
                });

                orders.push(order);
                orderById[_orderId.current()] = order;
                orderIdByAddress[_orderId.current()] = msg.sender;
                marketStatusForSender[_marketId][msg.sender] = true;
                cost = _amount;
                positionBySenderAndMarketId[_marketId][msg.sender] = _position;
                positionSize = newSize;

            // this is a condition for a market that is already being traded by the sender  
            } else if(marketStatusForSender[_marketId][msg.sender] == true) {
                if(_position == Position.LONG) {
                    // logic to be executed if the previous position on the market is long
                    if(positionBySenderAndMarketId[_marketId][msg.sender] == Position.LONG) {
                        Order memory order = Order({
                            orderId: _orderId.current(),
                            sender: msg.sender,
                            marketId: _marketId,
                            position: _position,
                            leverage: _leverage,
                            amount: _amount
                        });

                        orders.push(order);
                        orderById[_orderId.current()] = order;
                        orderIdByAddress[_orderId.current()] = msg.sender;
                        marketStatusForSender[_marketId][msg.sender] = true;
                        positionSize = oldSize + newSize;

                        positionBySenderAndMarketId[_marketId][msg.sender] = _position;

                    // logic to be executed if the previous position on the market is short
                    } else if(positionBySenderAndMarketId[_marketId][msg.sender] == Position.SHORT) {
                        Order memory order = Order({
                            orderId: _orderId.current(),
                            sender: msg.sender,
                            marketId: _marketId,
                            position: _position,
                            leverage: _leverage,
                            amount: _amount
                        });

                        orders.push(order);
                        orderById[_orderId.current()] = order;
                        orderIdByAddress[_orderId.current()] = msg.sender;
                        marketStatusForSender[_marketId][msg.sender] = true;

                        if(newSize > oldSize) {
                            positionSize =  newSize - oldSize;
                            positionBySenderAndMarketId[_marketId][msg.sender] = Position.SHORT;
                        } else if(newSize < oldSize) {
                            positionSize =  oldSize - newSize;
                            positionBySenderAndMarketId[_marketId][msg.sender] = Position.LONG;
                        }
                    }
                } else if(_position == Position.SHORT) {
                    // logic to be executed if the previous position on the market is long
                    if(positionBySenderAndMarketId[_marketId][msg.sender] == Position.LONG) {
                        Order memory order = Order({
                            orderId: _orderId.current(),
                            sender: msg.sender,
                            marketId: _marketId,
                            position: _position,
                            leverage: _leverage,
                            amount: _amount
                        });

                        orders.push(order);
                        orderById[_orderId.current()] = order;
                        orderIdByAddress[_orderId.current()] = msg.sender;

                        if(newSize > oldSize) {
                            marketStatusForSender[_marketId][msg.sender] = true;
                            positionSize =  newSize - oldSize;
                            positionBySenderAndMarketId[_marketId][msg.sender] = Position.LONG;
                        } else if(newSize < oldSize) {
                            marketStatusForSender[_marketId][msg.sender] = true;
                            cost = getCostFromMarketIdAndAddress(_marketId, msg.sender) - _amount;
                            positionSize =  oldSize - newSize;
                            positionBySenderAndMarketId[_marketId][msg.sender] = Position.SHORT;
                        } else if(newSize == oldSize) {
                            marketStatusForSender[_marketId][msg.sender] = false;
                            cost = _amount - getCostFromMarketIdAndAddress(_marketId, msg.sender);
                            positionSize = 0;
                            positionBySenderAndMarketId[_marketId][msg.sender] = Position.NIL;
                        }

                    // logic to be executed if the previous position on the market is short
                    } else if(positionBySenderAndMarketId[_marketId][msg.sender] == Position.SHORT) {
                        Order memory order = Order({
                            orderId: _orderId.current(),
                            sender: msg.sender,
                            marketId: _marketId,
                            position: _position,
                            leverage: _leverage,
                            amount: _amount
                        });

                        orders.push(order);
                        orderById[_orderId.current()] = order;
                        orderIdByAddress[_orderId.current()] = msg.sender;
                        marketStatusForSender[_marketId][msg.sender] = true;
                        positionSize =  oldSize + newSize;
                        positionBySenderAndMarketId[_marketId][msg.sender] = Position.SHORT;
                    }
                }     
            }
            
            averageLeverage = positionSize / cost;

            leverageBySenderAndMarketId[_marketId][msg.sender] = averageLeverage;
            costBySenderAndMarketId[_marketId][msg.sender] = cost;
            primex.transfer(address(this), _amount);
            emit OrderCreated(_orderId.current(), msg.sender, _marketId, _position, averageLeverage, msg.value);
            return (cost, averageLeverage);
        }

    function getCostFromMarketIdAndAddress(uint256 _marketId, address _user) 
        public 
        view 
        returns (uint256) 
        {
            return costBySenderAndMarketId[_marketId][_user];
        }
    
    function getLeveregeFromMarketIdAndAddress(uint256 _marketId, address _user)
        public
        view
        returns (uint256)
        {
            return leverageBySenderAndMarketId[_marketId][_user];
        }

    function getPNL(uint256 _marketId, address _user) public view returns (uint256) {
        return pnlBySenderAndMarketId[_marketId][_user];
    }
/*
    function closeTrade(uint256 _marketId) public view returns (uint256) {
        Total memory total = Total({
            marketId: _marketId,
            user: msg.sender,
            initialTotal: 
            finalTotal:
        });
        totals.push(total);
        uint256 profitOrLoss = getPNL(_marketId, _user);
        return profitOrLoss; 
    }
*/
}