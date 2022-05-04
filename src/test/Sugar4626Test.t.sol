// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {TestFixture} from "./utils/TestFixture.sol";
import {StrategyParams} from "@yearnvaults/contracts/BaseStrategy.sol";
import {Sugar4626} from "../Sugar4626.sol";
import "forge-std/console.sol";

contract Sugar4626Test is TestFixture {
    Sugar4626 public sugar;

    function setUp() public override {
        super.setUp();

        sugar = new Sugar4626(address(vaultWrapper), address(vault));
    }

    function _mintYieldTokenShares(address _receiver, uint256 _amount) private {
        uint256 _amountUnderlying = vaultWrapper.previewMint(_amount);
        deal(address(want), _receiver, _amountUnderlying);

        vm.startPrank(_receiver);
        want.approve(address(vaultWrapper), _amountUnderlying);
        want.approve(address(vault), _amountUnderlying);
        vault.approve(address(vaultWrapper), type(uint256).max);
        uint256 _shares = vaultWrapper.deposit(_amountUnderlying, _receiver);
        vm.stopPrank();

        assertEq(_shares, _amount);
        // assertEq(yToken.balanceOf(_receiver), _amount);
    }

    function testSetupOk() public {
        console.log("address of sugar contract", address(sugar));
        assertTrue(address(0) != address(sugar));
        assertEq(sugar.vault(), address(vault));
        assertEq(sugar.yieldToken(), address(vaultWrapper));
    }

    function testStake(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        _mintYieldTokenShares(user, _amount);
    }
}
