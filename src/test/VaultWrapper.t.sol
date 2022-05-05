// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {TestFixture} from "./utils/TestFixture.sol";
import {StrategyParams} from "@yearnvaults/contracts/BaseStrategy.sol";
import "forge-std/console.sol";

contract VaultWrapperTest is TestFixture {
    function setUp() public override {
        super.setUp();
    }

    function testSetupVaultOK() public {
        console.log("address of vault", address(vault));
        assertTrue(address(0) != address(vault));
        assertEq(vault.token(), address(want));
        assertEq(vault.depositLimit(), type(uint256).max);
    }

    function testSetupWrapperOK() public {
        console.log("address of wrapper", address(vaultWrapper));
        assertTrue(address(0) != address(vaultWrapper));
        assertEq(vaultWrapper.asset(), address(want));
    }

    function testSetupStrategyOK() public {
        console.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(address(strategy.vault()), address(vault));
        assertTrue(vault.strategies(address(strategy)).activation > 0);
    }

    function testERC20Compatibility(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        deal(address(want), whale, _amount);
        vm.startPrank(whale);
        want.approve(address(vaultWrapper), _amount);

        uint256 _shares = vaultWrapper.deposit(_amount, whale);
        assertEq(vaultWrapper.balanceOf(whale), _shares);
        vaultWrapper.transfer(user, _amount);
        vm.stopPrank();

        assertRelApproxEq(want.balanceOf(address(vault)), _amount, DELTA);
        assertEq(vaultWrapper.balanceOf(user), _shares);
        assertEq(vaultWrapper.balanceOf(whale), 0);
        assertEq(vaultWrapper.maxRedeem(user), _shares);
        assertEq(vault.balanceOf(address(vaultWrapper)), _shares);
        assertEq(vaultWrapper.totalSupply(), _shares);
    }

    function testDeposit(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        deal(address(want), user, _amount);
        vm.startPrank(user);
        want.approve(address(vaultWrapper), _amount);

        uint256 _shares = vaultWrapper.deposit(_amount, user);
        vm.stopPrank();

        assertRelApproxEq(want.balanceOf(address(vault)), _amount, DELTA);
        assertEq(vaultWrapper.balanceOf(user), _shares);
        assertEq(vaultWrapper.maxRedeem(user), _shares);
        assertEq(vault.balanceOf(address(vaultWrapper)), _shares);
        assertEq(vaultWrapper.totalSupply(), _shares);
    }

    function testWithdraw(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        deal(address(want), user, _amount);

        uint256 balanceBefore = want.balanceOf(address(user));
        vm.startPrank(user);
        want.approve(address(vaultWrapper), _amount);
        uint256 _shares = vaultWrapper.deposit(_amount, user);
        vm.stopPrank();
        assertRelApproxEq(want.balanceOf(address(vault)), _amount, DELTA);
        assertEq(vaultWrapper.balanceOf(user), _shares);
        assertEq(vaultWrapper.maxRedeem(user), _shares);

        skip(3 minutes);

        uint256 withdrawAmount = vaultWrapper.maxWithdraw(user);
        vm.prank(user);
        vaultWrapper.withdraw(withdrawAmount, user, user);

        assertRelApproxEq(want.balanceOf(user), balanceBefore, DELTA);
        assertEq(vaultWrapper.balanceOf(user), 0);
    }

    function testStrategyOperation(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        deal(address(want), user, _amount);

        uint256 balanceBefore = want.balanceOf(address(user));
        vm.startPrank(user);
        want.approve(address(vaultWrapper), _amount);
        uint256 _shares = vaultWrapper.deposit(_amount, user);
        vm.stopPrank();
        assertRelApproxEq(want.balanceOf(address(vault)), _amount, DELTA);
        assertEq(vaultWrapper.balanceOf(user), _shares);
        assertEq(vaultWrapper.maxRedeem(user), _shares);

        skip(3 minutes);

        vm.prank(strategist);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        uint256 withdrawAmount = vaultWrapper.maxWithdraw(user);
        vm.prank(user);
        vaultWrapper.withdraw(withdrawAmount, user, user);

        assertRelApproxEq(want.balanceOf(user), balanceBefore, DELTA);
        assertEq(vaultWrapper.balanceOf(user), 0);
    }

    function testProfitableHarvest(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        deal(address(want), user, _amount);
        deal(address(want), address(this), _amount / 2);

        // Deposit to the vault
        vm.startPrank(user);
        want.approve(address(vaultWrapper), _amount);
        uint256 _shares = vaultWrapper.deposit(_amount, user);
        vm.stopPrank();
        assertEq(vaultWrapper.balanceOf(user), _shares);
        assertRelApproxEq(want.balanceOf(address(vault)), _amount, DELTA);

        uint256 beforePps = vault.pricePerShare();
        console.log("beforePps", beforePps);
        uint256 wrapperPps = vaultWrapper.convertToAssets(1) *
            10**vault.decimals();
        console.log("yTokenPps", wrapperPps);
        assertEq(beforePps, wrapperPps);

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
