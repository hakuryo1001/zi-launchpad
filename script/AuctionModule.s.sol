pragma solidity >=0.8.0;

import {AuctionModule} from "../src/AuctionModule.sol";
import {Zi} from "../lib/zi-token/src/Zi.sol";
import {BaseScript} from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract AuctionModuleScript is BaseScript {
    function run() public broadcaster returns (AuctionModule am) {
        uint256 decimals = 1e18;
        uint256 initialSupply = 1e5 * decimals;
        uint256 supplyLimit = 1e6 * decimals;

        uint256 launchpadAmount = initialSupply;
        uint256 initialAuctionPrice = 1 ether;
        uint256 timeToEmitAll = 52 weeks;

        Zi zi = new Zi(initialSupply, supplyLimit);
        am = new AuctionModule(
            address(zi),
            launchpadAmount,
            initialAuctionPrice,
            timeToEmitAll
        );
    }
}
