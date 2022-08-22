// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

//import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PrimeX.sol";

contract PrimeExchange {

    //AggregatorV3Interface internal priceFeed; // to be used as update comes

    PrimeX public primex;
    uint256 public primeXPerEth;

    event BuyPrimeX(address buyer, uint256 amountOfETH, uint256 amountOfPrimeX);
    event SellPrimeX(address seller, uint256 amountOfPrimeX, uint256 amountOfETH);

    constructor(address _primeXAddress) {
        primex = PrimeX(_primeXAddress);
    }
    
    function setRate(uint256 _primeXPerEth) public {
        primeXPerEth = _primeXPerEth;
    }

    function buyPrimeX() public payable {
        require(
            primex.balanceOf(address(this)) >= (msg.value * primeXPerEth),
            "ERC20: transfer amount exceeds balance"
        );
        uint256 amount = msg.value * primeXPerEth;
        primex.transfer(msg.sender, amount);
        emit BuyPrimeX(msg.sender, msg.value, amount);
    }

    function sellPrimeX(uint256 amount) public payable {
        primex.approve(address(this), amount);
        primex.transferFrom(msg.sender, address(this), amount);
        uint256 ethAmount = amount / primeXPerEth;
        (bool sent, ) = msg.sender.call{value: ethAmount}("");
        require(sent, "Failed to send Ether");
        emit SellPrimeX(msg.sender, amount, ethAmount);
    }

    function withdraw() public payable {
        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }
}