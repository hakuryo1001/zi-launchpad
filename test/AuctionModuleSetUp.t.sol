pragma solidity >=0.8.0;

import {PRBTest} from "../lib/prb-test/src/PRBTest.sol";
import {console2} from "forge-std/console2.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Zi} from "../lib/zi-token/src/Zi.sol";
import {console} from "forge-std/console.sol";
import {AuctionModule} from "../src/AuctionModule.sol";
import "../lib/prb-math/src/SD59x18.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract AuctionModuleSetUp is PRBTest, StdCheats {
    Zi zi;
    AuctionModule am;

    address alice = address(0xAA); // alice is designated the owner of the pizza contract
    address bob = address(0xBB);
    address carol = address(0xCC);
    address dominic = address(0xDD);

    uint256 decimals = 1e18;

    uint256 ownerAmount = 1e5 * decimals; // The ether is here is to stand in proxy for the decimals for the token - nothing to do with the calculational decimals
    uint256 launchpadAmount = 1e5 * decimals;

    uint256 _initialSupply = launchpadAmount;
    uint256 _supplyLimit = 1e6 * decimals;

    function setUp() public {
        zi = new Zi(_initialSupply, _supplyLimit);
        am = new AuctionModule(address(zi), launchpadAmount, 1 ether, 52 weeks);
        zi.transfer(address(am), launchpadAmount);
        zi.mint(zi.owner(), ownerAmount);
    }

    function test_basicTest() public {
        assertEq(zi.owner(), address(this));
        assertEq(zi.balanceOf(address(this)), ownerAmount);
        assertEq(zi.balanceOf(address(am)), launchpadAmount);
    }

    function test_halflife() public {
        console.log("halflife:", am.halflife());
        assertEq(am.halflife(), 1 days);
        vm.warp(1 weeks);
        assertLte(am.halflife(), 1 days + 1 weeks); // not equal due to rounding errors
    }

    // function test_decimals() public {
    //     int256 x = 1e19
    // }

    function test_time_limits() public {
        console.log(
            "day 0 purchasePrice:",
            am.purchasePrice(uint256(1 ether)),
            "wei"
        );
        assertEq(am.purchasePrice(1 ether), 314893079349452644075);
        vm.warp(1 days);
        console.log(
            "day 1 purchasePrice:",
            am.purchasePrice(uint256(1 ether)),
            "wei"
        );
        assertEq(am.purchasePrice(1 ether), 157447802800458982686);
        vm.warp(2 days);
        console.log(
            "day 2 purchasePrice:",
            am.purchasePrice(uint256(1 ether)),
            "wei"
        );
        assertEq(am.purchasePrice(1 ether), 78723901400232171293);
        vm.warp(21 days);
        console.log(
            "day 21 purchasePrice:",
            am.purchasePrice(uint256(1 ether)),
            "wei"
        );
        assertEq(am.purchasePrice(1 ether), 150153925650144);
        // // on the 21st day, the purchase price will be 0.0001 Eth, which gives a FDV of 200k usd.

        vm.warp(22 days);
        console.log(
            "day 22 purchasePrice:",
            am.purchasePrice(uint256(1 ether)),
            "wei"
        );
        assertEq(am.purchasePrice(1 ether), 75076962825072);
        vm.warp(203 days);
        console.log(
            "day 203 purchasePrice:",
            am.purchasePrice(uint256(1 ether)),
            "wei"
        );
        assertEq(am.purchasePrice(1 ether), 0);
    }

    function test_buy_limits() public {
        vm.warp(21 days);
        console.log(
            "day 21 purchasePrice:",
            am.purchasePrice(uint256(1 ether)),
            "wei"
        );
        assertEq(am.purchasePrice(1 ether), 150153925650144);
        vm.warp(21 days);
        vm.expectRevert("Buying more than 10% of the remaining supply");
        console.log(
            "day 21 purchasePrice, buy amount: 1e5 * 1e18:",
            am.purchasePrice(uint256(1e5 ether)),
            "wei"
        );
    }

    function test_price() public {
        // console.log(uint256(unwrap(sd(2e18))));
        // console.logInt(unwrap(sd(2e18)));
        // uint256 purchasePrice = am.purchasePrice(uint256(1e18));
        // console.log("purchase price:", purchasePrice / 1 ether, "ether");
    }

    function test_view_stuff() public {
        vm.warp(203 days);

        console.log("emission rate:", am.emissionRate());
        console.log("decay constant:", am.decayConstant());
        console.log("halflife:", am.halflife());
        console.log("criticalTime:", am.criticalTime());
        console.log("criticalAmount:", am.criticalAmount());
        console.log(
            "day 203 purchasePrice:",
            am.purchasePrice(uint256(1 ether)),
            "wei"
        );
    }
}
