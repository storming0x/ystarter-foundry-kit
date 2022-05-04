// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {TestFixture} from "./utils/TestFixture.sol";
import {StrategyParams} from "@yearnvaults/contracts/BaseStrategy.sol";
import "forge-std/console.sol";


contract YieldTokenTest is TestFixture {
    function setUp() public override {
        super.setUp();
    }

     function testSetupVaultOK() public {
        console.log("address of vault", address(vault));
        assertTrue(address(0) != address(vault));
        assertEq(vault.token(), address(want));
        assertEq(vault.depositLimit(), type(uint256).max);
    }

    function testSetupStrategyOK() public {
        console.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(address(strategy.vault()), address(vault));
        assertTrue(vault.strategies(address(strategy)).activation > 0);
    }

    function testStrategyOperation(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        deal(address(want), user, _amount);

        uint256 balanceBefore = want.balanceOf(address(user));
        vm.startPrank(user);
        want.approve(address(yToken), _amount);
        want.approve(address(vault), _amount);
        vault.approve(address(yToken), type(uint256).max);
        uint256 _shares = yToken.deposit(_amount, user);
        vm.stopPrank();
        assertRelApproxEq(want.balanceOf(address(vault)), _amount, DELTA);
        assertEq(vault.balanceOf(user), _shares);

        skip(3 minutes);
        
        vm.prank(strategist);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        uint256 withdrawAmount = yToken.maxWithdraw(user);
        vm.prank(user);
        yToken.withdraw(withdrawAmount, user, user);

        assertRelApproxEq(want.balanceOf(user), balanceBefore, DELTA);
    }

    function testProfitableHarvest(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        deal(address(want), user, _amount);
        deal(address(want), address(this), _amount / 2);

        // Deposit to the vault
        vm.startPrank(user);
        want.approve(address(yToken), _amount);
        want.approve(address(vault), _amount);
        vault.approve(address(yToken), type(uint256).max);
        uint256 _shares = yToken.deposit(_amount, user);
        vm.stopPrank();
        assertEq(vault.balanceOf(user), _shares);
        assertRelApproxEq(want.balanceOf(address(vault)), _amount, DELTA);

        uint256 beforePps = vault.pricePerShare();
        console.log("beforePps", beforePps);
        uint256 yTokenPps = yToken.convertToAssets(1) * 10 ** vault.decimals();
        console.log("yTokenPps", yTokenPps);
        assertEq(beforePps, yTokenPps);

        // Harvest 1: Send funds through the strategy
        skip(1);
        vm.prank(strategist);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        // Airdrop gains to the strategy
        want.transfer(address(strategy), want.balanceOf(address(this)));

        // Harvest 2: Realize profit
        skip(1);
        vm.prank(strategist);
        strategy.harvest();
        skip(6 hours);

        // check profits
        uint256 profit = want.balanceOf(address(vault));
        assertGt(want.balanceOf(address(strategy)) + profit, _amount);
        assertGt(vault.pricePerShare(), beforePps);
    }
}