// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";

import "./PrimeX.sol";
import "./PrimeMarket.sol";
import "./PrimeAccessibility.sol";
import "./PrimeAdmin.sol";

contract PrimeTrade is PrimeMarket, PrimeAccessibility {

    PrimeX public primex;

    using Counters for Counters.Counter;
    Counters.Counter private _orderId;

    mapping(uint256 => Order) public orderById;

    mapping(uint256 => address) public orderIdByAddress;

    mapping(uint256 => uint256) public pnlByOrderId;

    mapping(uint256 => mapping(address => bool)) public marketStatusForSender;

    mapping(uint256 => mapping(address => uint256)) public costBySenderAndMarketId;
    mapping(uint256 => mapping(address => uint256)) public leverageBySenderAndMarketId;
    mapping(uint256 => mapping(address => uint256)) public sizeBySenderAndMarketId;
    mapping(uint256 => mapping(address => uint256)) public priceBySenderAndMarketId;
    mapping(uint256 => mapping(address => uint256)) public pnlBySenderAndMarketId;

    mapping(uint256 => mapping(address => Position)) public positionBySenderAndMarketId;

    event OrderCreated(
        uint256 orderId, 
        address sender, 
        uint256 marketId, 
        Position position,
        uint256 leverage,
        uint256 amount
    );
    event TradeClosed(uint256 orderId, address sender, uint256 marketId, uint256 pnl);

    event BuyPrimeX(address buyer, uint256 amountOfETH, uint256 amountOfPrimeX);
    event SellPrimeX(address seller, uint256 amountOfPrimeX, uint256 amountOfETH);

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
    Order[] public orders;

    function placeOrder(uint256 _marketId, Position _position, uint256 _leverage, uint256 _amount) 
        public
        onlyPrimeAccounts
        returns (uint256, uint256)
        {   
            if(isActive[_marketId] == false) { revert MarketUntradeable(); } 
            if(_leverage > 10) { revert LeverageLimit(); }
            require(_amount > 0, "Amount to be traded must be greater than 0");

            _leverage = _leverage * 10 ** 8;
            _amount = _amount * 10 ** 8;

            _orderId.increment();
            uint256 positionSize;
            uint256 averageLeverage;

            uint256 tradePrice = getLatestUnitPriceById(_marketId);
            uint256 cost = costBySenderAndMarketId[_marketId][msg.sender] + _amount;
            uint256 updatedSize = costBySenderAndMarketId[_marketId][msg.sender] * leverageBySenderAndMarketId[_marketId][msg.sender];
            uint256 newSize = _amount * _leverage;


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
                        positionSize = updatedSize + newSize;

                        positionBySenderAndMarketId[_marketId][msg.sender] = Position.LONG;

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

                        if(newSize > updatedSize) {
                            positionSize =  newSize - updatedSize;
                            positionBySenderAndMarketId[_marketId][msg.sender] = Position.LONG;

                        } else if(newSize < updatedSize) {
                            positionSize =  updatedSize - newSize;
                            positionBySenderAndMarketId[_marketId][msg.sender] = Position.SHORT;

                        } else if(newSize == updatedSize) {
                            marketStatusForSender[_marketId][msg.sender] = false;
                            positionSize = 0;
                            positionBySenderAndMarketId[_marketId][msg.sender] = Position.NIL;
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
                        marketStatusForSender[_marketId][msg.sender] = true;

                        if(newSize > updatedSize) {
                            positionSize =  newSize - updatedSize;
                            positionBySenderAndMarketId[_marketId][msg.sender] = Position.SHORT;

                        } else if(newSize < updatedSize) {
                            positionSize =  updatedSize - newSize;
                            positionBySenderAndMarketId[_marketId][msg.sender] = Position.LONG;

                        } else if(newSize == updatedSize) {
                            marketStatusForSender[_marketId][msg.sender] = false;
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
                        positionSize =  updatedSize + newSize;
                        positionBySenderAndMarketId[_marketId][msg.sender] = Position.SHORT;
                    }
                }     
            }
            
            averageLeverage = positionSize / cost;

            leverageBySenderAndMarketId[_marketId][msg.sender] = averageLeverage;
            costBySenderAndMarketId[_marketId][msg.sender] = cost;
            priceBySenderAndMarketId[_marketId][msg.sender] = tradePrice;

            primex.approve(address(this), _amount);
            primex.transferFrom(msg.sender, address(this), _amount);
            emit OrderCreated(_orderId.current(), msg.sender, _marketId, _position, _leverage, _amount);
            return (cost, averageLeverage);
        }

    function closeOrder(uint256 _marketId) public onlyPrimeAccounts returns (uint256, bool) {
        require(marketStatusForSender[_marketId][msg.sender] == true, "The market is not presently traded by sender");
        marketStatusForSender[_marketId][msg.sender] = false;

        uint256 profit;
        uint256 loss;
        uint256 returned;
        bool pnl;
        uint256 cost = costBySenderAndMarketId[_marketId][msg.sender];
        uint256 tradePrice = priceBySenderAndMarketId[_marketId][msg.sender];
        uint256 closePrice = unitPriceById[_marketId];
        uint256 tradeRatio = closePrice / tradePrice;

        uint256 initialSize = sizeBySenderAndMarketId[_marketId][msg.sender];
        uint256 finalSize = initialSize * tradeRatio;

        if(positionBySenderAndMarketId[_marketId][msg.sender] == Position.LONG) {
            if(finalSize > initialSize) {
                profit = finalSize - initialSize;
                returned = cost + profit;
                pnl = true;
            } else if(finalSize <= initialSize) {
                loss = initialSize - finalSize;
                returned = cost - loss;
                pnl = false;
            }

        } else if(positionBySenderAndMarketId[_marketId][msg.sender] == Position.SHORT) {
            if(finalSize > initialSize) {
                loss = finalSize - initialSize;
                returned = cost - loss;
                pnl = false;
            } else if(finalSize <= initialSize) {
                profit = initialSize - finalSize;
                returned = cost + profit;
                pnl = true;
            }
        }
        
        primex.transfer(msg.sender, returned);
        return (returned, pnl);
    }

   function getCostFromMarketIdAndAddress(uint256 _marketId, address _user) 
        public 
        view 
        returns (uint256) 
        {
            return costBySenderAndMarketId[_marketId][_user];
        }

    function getPriceLiquidated(uint256 _marketId, address _user) public view returns (uint256) {
        uint256 leverageUsed = leverageBySenderAndMarketId[_marketId][_user];
        uint256 liquidationRatio = 100 / leverageUsed;
        uint256 tradePrice = priceBySenderAndMarketId[_marketId][_user];
        return tradePrice / liquidationRatio;
    }
}