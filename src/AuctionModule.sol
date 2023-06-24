pragma solidity >=0.8.0;
import {console} from "../lib/forge-std/src/console.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Context} from "../lib/openzeppelin-contracts/contracts/utils/Context.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {SD59x18, sd, unwrap, ln, gt, frac} from "../lib/prb-math/src/SD59x18.sol";

contract AuctionModule is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public token;

    address public tokenAddress;
    uint256 public totalAuctionAmount;
    uint256 public totalAmountSold;
    int256 public limit = 133_084258667509499441;

    int256 public initialAuctionPrice;

    int256 public sd59x18_decimals = 1e18;

    int256 public lastAvailableAuctionStartTime;
    int256 public startTime;

    int256 public timeToEmitAll; // measured in seconds

    /// @param _tokenAddress - the address that is being auctioned.
    /// @param _totalAuctionAmount - input the amount but in 18 decimals: so 1 token would be 1000000000000000000.
    /// @param _initialAuctionPrice - input the amount in 18 decimals. Since the buy amount is measured in 18 decimals, the initialAuctionprice is the price for the smallest unit of the token
    /// @param _timeToEmitAll - input the amount in seconds
    /// @param _totalAuctionAmount - input the amount but in 18 decimals: so 1 token would be 1000000000000000000.
    /// _totalAuctionAmount, _initialAuctionPrice, _timeToEmitAll, _totalAuctionAmount are NOT multiplied with 1e18
    /// This is because we don't want to confuse the user when they call the view functions
    /// View functions will return int256s with full token decimals
    /// The decimals necessary for SD59x18 calculation will be reserved for internal use
    constructor(
        address _tokenAddress,
        uint256 _totalAuctionAmount,
        uint256 _initialAuctionPrice,
        uint256 _timeToEmitAll
    ) {
        tokenAddress = _tokenAddress;
        token = IERC20(_tokenAddress);
        totalAuctionAmount = _totalAuctionAmount;
        initialAuctionPrice = int256(_initialAuctionPrice);
        lastAvailableAuctionStartTime = int256(block.timestamp);
        startTime = int256(block.timestamp);
        timeToEmitAll = int256(_timeToEmitAll);
    }

    function depositInitialReserves() public onlyOwner {
        token.transferFrom(owner(), address(this), totalAuctionAmount);
    }

    function withdrawReserves(uint256 amount) public onlyOwner {
        token.transfer(owner(), amount);
    }

    function _claimPurchase(address _to, uint256 _amount) internal {
        token.transfer(_to, _amount);
    }

    // The first instance of SD59x18 should already be multiplied with decimals

    function _hl() internal view returns (SD59x18) {
        return sd(1 days * sd59x18_decimals);
    }

    function halflife() public view returns (uint256) {
        uint256 _halflife = uint256(unwrap(_hl()) / sd59x18_decimals);
        return _halflife;
        // Returns the halflife without the sd59x18_decimals.
        // This breaks convention with the decayConstant(), which does return the value with sd59x18_decimals.
    }

    // https://ethereum.stackexchange.com/questions/107287/why-do-you-have-to-wrap-a-uint-around-a-number-when-dividing-it-and-there-is-a
    function _dc() internal view returns (SD59x18) {
        SD59x18 _halfLife = _hl();
        SD59x18 _decayConstant = ln(sd(2e18)).div(_halfLife);
        // Returns already with sd59x18_decimals.
        return _decayConstant;
    }

    function decayConstant() external view returns (uint256) {
        uint256 _decayConstant = uint256(unwrap(_dc()));
        // Returns the decayConstant with sd59x18 decimals
        return _decayConstant;
    }

    function _r() internal view returns (SD59x18) {
        // returns already with sd59x18_decimals.
        return
            sd(int256(totalAuctionAmount) * sd59x18_decimals).div(
                sd(timeToEmitAll * sd59x18_decimals)
            );
    }

    function emissionRate() external view returns (uint256) {
        uint256 r = uint256(unwrap(_r()) / sd59x18_decimals);
        // Returns the halflife without the sd59x18_decimals.
        return r;
    }

    function _ct() internal view returns (SD59x18) {
        SD59x18 _decayConstant = _dc();
        SD59x18 _limit = sd(limit);
        SD59x18 _criticalTime = _limit.div(_decayConstant);
        return _criticalTime;
    }

    function criticalTime() external view returns (uint256) {
        return uint256(unwrap(_ct()));
    }

    function _ca() internal view returns (SD59x18) {
        SD59x18 _decayConstant = _dc();
        SD59x18 _limit = sd(limit); // the decimal points of limit make it unnecessary to multiply it with sd59x18_decimals
        SD59x18 _emissionRate = _r();
        SD59x18 _criticalAmount = _limit.mul(_emissionRate).div(_decayConstant);
        return _criticalAmount;
    }

    function criticalAmount() external view returns (uint256) {
        return uint256(unwrap(_ca()));
    }

    function _num2(
        SD59x18 _quantity,
        SD59x18 _halfLife,
        SD59x18 _emissionRate,
        SD59x18 _decayConstant,
        SD59x18 _limit
    ) internal view returns (SD59x18) {
        SD59x18 _criticalAmount = _ca();
        if (gt(_quantity, _criticalAmount)) {
            console.log("_quantity > _criticalAmount");
        } else {
            console.log("_quantity < _criticalAmount");
        }

        SD59x18 n2 = (
            gt(_quantity, _criticalAmount)
                ? (_limit - sd(int256(1) * sd59x18_decimals)).exp() -
                    sd(int256(1) * sd59x18_decimals)
                : _decayConstant.mul(_quantity).div(_emissionRate).exp() -
                    sd(int256(1) * sd59x18_decimals)
        );
        return n2;
    }

    function _den(
        SD59x18 timeSinceLastAuctionStart,
        SD59x18 _decayConstant,
        SD59x18 _limit
    ) internal view returns (SD59x18) {
        SD59x18 _criticalTime = _ct();
        // if (gt(timeSinceLastAuctionStart, _criticalTime)) {
        //     console.log("timeSinceLastAuctionStart > _criticalTime)");
        // } else {
        //     console.log("timeSinceLastAuctionStart <_criticalTime!");
        // }
        SD59x18 d = (
            gt(timeSinceLastAuctionStart, _criticalTime)
                ? (_limit - sd(int256(1) * sd59x18_decimals)).exp()
                : _decayConstant.mul(timeSinceLastAuctionStart).exp()
        );

        return d;
    }

    ///@notice calculate purchase price using exponential continuous GDA formula
    ///@param numTokens - please enter amount with full 18 decimals behind (so 1 token would be 1000000000000000000)
    // Price is returned in wei
    // This is to make things easier for etherscan calls
    function purchasePrice(uint256 numTokens) public view returns (uint256) {
        require(
            int256(numTokens) <
                int256(totalAuctionAmount - totalAmountSold) / 10,
            "Buying more than 10% of the remaining supply"
        );

        SD59x18 _quantity = sd(int256(numTokens) * sd59x18_decimals);
        SD59x18 _limit = sd(limit);
        SD59x18 _initialAuctionPrice = sd(
            initialAuctionPrice * sd59x18_decimals
        );
        SD59x18 _decayConstant = _dc();
        SD59x18 _halfLife = _hl();
        SD59x18 _emissionRate = _r();

        SD59x18 timeSinceLastAuctionStart = sd(
            (int256(block.timestamp) - lastAvailableAuctionStartTime) *
                sd59x18_decimals
        );

        SD59x18 num1 = _initialAuctionPrice.div(_decayConstant);

        // SD59x18 num2 = (_decayConstant.mul(_quantity).div(_emissionRate))
        //     .exp() - sd(int256(1) * sd59x18_decimals);
        // SD59x18 den = (_decayConstant.mul(timeSinceLastAuctionStart)).exp();

        // SD59x18 num2 = (
        //     gt(_quantity, _criticalAmount)
        //         ? (_halfLife.div(_emissionRate)).mul(
        //             (_quantity - _criticalAmount).mul(
        //                 (_decayConstant.mul(_quantity).div(_emissionRate).exp())
        //             ) + _criticalAmount
        //         )
        //         : _decayConstant.mul(_quantity).div(_emissionRate).exp() -
        //             sd(int256(1))
        // );
        // SD59x18 den = (
        //     gt(timeSinceLastAuctionStart, _criticalTime)
        //         ? (timeSinceLastAuctionStart -
        //             _decayConstant.mul(_limit) +
        //             sd(int256(1))).mul((_limit - sd(int256(1))).exp())
        //         : _decayConstant.mul(timeSinceLastAuctionStart).exp()
        // );

        SD59x18 num2 = _num2(
            _quantity,
            _halfLife,
            _emissionRate,
            _decayConstant,
            _limit
        );
        SD59x18 den = _den(timeSinceLastAuctionStart, _decayConstant, _limit);

        SD59x18 cost = ((num2).div(den)).mul(num1);

        // console.log("num2");
        // console.logInt(unwrap(num2));
        // console.log("_____");
        // console.log("den");
        // console.logInt(unwrap(den));
        // console.log("_____");
        // console.log("(num2).div(den)");
        // console.logInt(unwrap((num2).div(den)));
        // console.log("_____");
        // console.log("num1");
        // console.logInt(unwrap(num1));
        // console.log("_____");

        // console.log("whole number part:");
        // console.logInt(unwrap(cost - frac(cost)));
        // console.log("without decimals part:");
        // console.logInt(unwrap(cost) / sd59x18_decimals);
        int256 finalCost = unwrap(cost) / sd59x18_decimals;
        return uint256(finalCost);
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
        int256 secondsOfEmissionsAvaiable = int256(block.timestamp) -
            lastAvailableAuctionStartTime;
        //number of seconds of emissions are being purchased
        int256 secondsOfEmissionsToPurchase = unwrap(
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

    function depositMoreForAuctioning(
        uint256 additionalAuctionAmount,
        uint256 extraTime
    ) public onlyOwner returns (bool) {
        token.transferFrom(owner(), address(this), additionalAuctionAmount);
        totalAuctionAmount += additionalAuctionAmount;
        timeToEmitAll += int256(extraTime);
        return true;
    }

    function rescueERC20(
        address tokenContract,
        address to,
        uint256 amount
    ) external onlyOwner {
        IERC20(tokenContract).transfer(to, amount);
    }
}
