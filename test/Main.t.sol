// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Main.sol";
import "../src/VRFv2Consumer.sol";
contract testMain is Test {
    Main public main;
    VRFv2Consumer public Vrf;
    function setUp() public {
        Vrf =new VRFv2Consumer(90);
        main = new Main {value:1 ether}(payable(0x5bD5473183CEe0EDcc5af3cc66F9b2C2C7bf6f41),Vrf );
  
    }

    function test_createNew() public returns (uint u){
        main.createNew{value:10 ether}("first", block.timestamp+ 30 minutes);
        main.double{value:20 ether}(0);

    }

 
}
