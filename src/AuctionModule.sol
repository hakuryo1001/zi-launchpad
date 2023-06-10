pragma solidity >=0.8.0;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Context} from "../lib/openzeppelin-contracts/contracts/utils/Context.sol";
import {SafeMath} from "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {SD59x18, sd, convert, ln, gt} from "../lib/prb-math/src/SD59x18.sol";

contract AuctionModule is Ownable {
    address public tokenAddress;
    IERC20 public token;
    uint256 public totalAuctionAmount;
    uint256 public totalAmountSold;
    int256 public limit = 133_084258667509499441;
    int256 public initialAuctionPrice;

    // int256 public startTime;
    int256 public halfLife; // measured in seconds

    int256 public lastAvailableAuctionStartTime;

    int256 public timeToEmitAll; // measured in seconds

    constructor(
        address _tokenAddress,
        uint256 _totalAuctionAmount,
        int256 _initialAuctionPrice,
        int256 _halfLife,
        int256 _lastAvailableAuctionStartTime,
        int256 _timeToEmitAll
    ) {
        tokenAddress = _tokenAddress;
        token = IERC20(_tokenAddress);
        totalAuctionAmount = _totalAuctionAmount;
        initialAuctionPrice = _initialAuctionPrice;
        halfLife = _halfLife;
        lastAvailableAuctionStartTime = int256(block.timestamp);
        timeToEmitAll = _timeToEmitAll;
    }

    function depositReserves(uint256 amount) public onlyOwner {
        token.transferFrom(owner(), address(this), amount);
    }

    function withdrawReserves(uint256 amount) public onlyOwner {
        token.transfer(owner(), amount);
    }

    function _claimPurchase(address _to, uint256 _amount) internal {
        token.transfer(_to, _amount);
    }

    function _r() internal view returns (SD59x18) {
        return sd(int256(totalAuctionAmount)).div(sd(timeToEmitAll));
    }

    function emissionRate() public view returns (int256) {
        return convert(_r());
    }

    function decayConstant() public view returns (int256) {
        int256 _decayConstant = convert(ln(sd(2)).div(sd(halfLife)));
        return _decayConstant;
    }

    error InsufficientAvailableTokens();
    error InsufficientPayment();
    error UnableToRefund();

    ///@notice purchase a specific number of tokens from the GDA
    function purchaseTokens(uint256 numTokens, address to) public payable {
        require(
            totalAmountSold + numTokens < totalAuctionAmount,
            "Exceeding the total auction amount"
        );
        //number of seconds of token emissions that are available to be purchased
        int256 secondsOfEmissionsAvaiable = convert(
            sd(int256(block.timestamp)) - sd(lastAvailableAuctionStartTime)
        );
        //number of seconds of emissions are being purchased
        int256 secondsOfEmissionsToPurchase = convert(
            sd(int256(numTokens)).div(_r())
        );
        //ensure there's been sufficient emissions to allow purchase
        if (secondsOfEmissionsToPurchase > secondsOfEmissionsAvaiable) {
            revert InsufficientAvailableTokens();
        }

        uint256 cost = purchasePrice(numTokens);
        if (msg.value < cost) {
            revert InsufficientPayment();
        }
        //mint tokens
        _claimPurchase(to, numTokens);
        //update last available auction
        lastAvailableAuctionStartTime += secondsOfEmissionsToPurchase;

        //refund extra payment
        uint256 refund = msg.value - cost;
        (bool sent, ) = msg.sender.call{value: refund}("");
        totalAmountSold += numTokens;
        if (!sent) {
            revert UnableToRefund();
        }
    }

    function _ct() internal view returns (SD59x18) {
        SD59x18 _decayConstant = sd(decayConstant());
        SD59x18 _limit = sd(limit);
        SD59x18 _criticalTime = _limit.div(_decayConstant);
        return _criticalTime;
    }

    function criticalTime() external view returns (int256) {
        return convert(_ct());
    }

    function _ca() internal view returns (SD59x18) {
        SD59x18 _decayConstant = sd(decayConstant());
        SD59x18 _limit = sd(limit);
        SD59x18 _emissionRate = _r();
        SD59x18 _criticalAmount = _limit.mul(_emissionRate).div(_decayConstant);
        return _criticalAmount;
    }

    function criticalAmount() external view returns (int256) {
        return convert(_ca());
    }

    // halflife programming - sd(int256(1 years - 1 weeks )).div(sd(int256(1 years)))).mul(timeSinceLastAuctionStart)
    ///@notice calculate purchase price using exponential continuous GDA formula
    function purchasePrice(uint256 numTokens) public view returns (uint256) {
        SD59x18 _criticalTime = _ct();
        SD59x18 _criticalAmount = _ca();
        SD59x18 _quantity = sd(int256(numTokens));
        SD59x18 _limit = sd(limit);
        SD59x18 timeSinceLastAuctionStart = sd(
            int256(block.timestamp) - lastAvailableAuctionStartTime
        );

        SD59x18 _decayConstant = sd(decayConstant());
        SD59x18 _halfLife = sd(halfLife);
        SD59x18 _emissionRate = _r();

        SD59x18 num1 = sd(initialAuctionPrice).div(_decayConstant);
        // SD59x18 num2 = _decayConstant.mul(_quantity).div(_emissionRate).exp() -
        //     sd(int256(1));
        SD59x18 num2 = (
            gt(_quantity, _criticalAmount)
                ? (_halfLife.div(_emissionRate)).mul(
                    (_quantity - _criticalAmount).mul(
                        (_decayConstant.mul(_quantity).div(_emissionRate).exp())
                    ) + _criticalAmount
                )
                : _decayConstant.mul(_quantity).div(_emissionRate).exp() -
                    sd(int256(1))
        );
        SD59x18 den = (
            gt(timeSinceLastAuctionStart, _criticalTime)
                ? (timeSinceLastAuctionStart -
                    _decayConstant.mul(_limit) +
                    sd(int256(1))).mul((_limit - sd(int256(1))).exp())
                : _decayConstant.mul(timeSinceLastAuctionStart).exp()
        );
        // SD59x18 den = _decayConstant.mul(timeSinceLastAuctionStart).exp();
        int256 totalCost = convert(num1.mul(num2).div(den));
        //total cost is already in terms of wei so no need to scale down before
        //conversion to uint. This is due to the fact that the original formula gives
        //price in terms of ether but we scale up by 10^18 during computation
        //in order to do fixed point math.
        return uint256(totalCost);
    }
}
