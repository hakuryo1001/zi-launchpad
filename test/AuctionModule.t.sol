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
    }

    function auctionModuleSetUp(
        uint256 _launchpadAmount,
        uint256 _initialAuctionPrice,
        uint256 _timeToEmitAll,
        uint256 _ownerAmount
    ) public {
        am = new AuctionModule(
            address(zi),
            _launchpadAmount,
            int256(_initialAuctionPrice),
            int256(_timeToEmitAll)
        );
        zi.transfer(address(am), _launchpadAmount);
        zi.mint(zi.owner(), _ownerAmount);
    }

    function test_basicTest() public {
        auctionModuleSetUp(launchpadAmount, 1 ether, 52 weeks, ownerAmount);
        assertEq(zi.owner(), address(this));
        assertEq(zi.balanceOf(address(this)), ownerAmount);
        assertEq(zi.balanceOf(address(am)), launchpadAmount);
    }

    function test_price_1() public {
        auctionModuleSetUp(launchpadAmount, 1 ether, 52 weeks, ownerAmount);
        uint256 purchasePrice = am.purchasePrice(1e18);
        console.log("purchase price:", purchasePrice);
        // console.log("purchase price:", purchasePrice / 1 ether, "ether");
        // assertEq(purchasePrice / 1 ether, 872541);
    }

    function test_price_2() public {
        auctionModuleSetUp(
            launchpadAmount,
            1.198712347890043212 ether,
            1 weeks,
            ownerAmount
        );
        uint256 purchasePrice = am.purchasePrice(1 * 1e18);

        console.log(
            "purchase price:",
            purchasePrice / (decimals * 1 ether),
            "ether"
        );
        vm.warp(1 weeks);
        console.log(
            "purchase price:",
            am.purchasePrice(1 * 1e18) / (decimals * 1 ether),
            "ether"
        );
        // assertEq(purchasePrice / 1 ether, 872541);
    }

    function test_limit() public {
        auctionModuleSetUp(launchpadAmount, 1 ether, 52 weeks, ownerAmount);
        console.logInt(unwrap(sd(int256(2 * 1e18)).exp()));
        // console.logInt(unwrap(sd(am.limit()).exp()));
        // console.logInt(unwrap(sd(134 * 1e18).exp()));
        // console.logInt(am.limit());
        // sd(am.limit()-1).exp();
    }
}
