// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {VaultAPI} from "@yearnvaults/contracts/BaseStrategy.sol";
import "./interfaces/IERC4626.sol";
import "./interfaces/IVaultWrapper.sol";

// TODO: integrate solmate ERC20 instead OZ.
// Needs to extract VaultAPI interface out of BaseStrategy to avoid collision
contract VaultWrapper is ERC20, IVaultWrapper, IERC4626 {
    VaultAPI public immutable yVault;
    address public immutable token;
    uint256 public immutable _decimals;

    constructor(VaultAPI _vault)
        ERC20(
            string(abi.encodePacked(_vault.name(), "4646adapter")),
            string(abi.encodePacked(_vault.symbol(), "4646"))
        )
    {
        yVault = _vault;
        token = yVault.token();
        _decimals = uint8(_vault.decimals());
    }

    function vault() external view returns (address) {
        return address(yVault);
    }

    // NOTE: this number will be different from this token's totalSupply
    function vaultTotalSupply() external view returns (uint256) {
        return yVault.totalSupply();
    }

    /*//////////////////////////////////////////////////////////////
                      ERC20 compatibility
   //////////////////////////////////////////////////////////////*/

    function decimals() public view override returns (uint8) {
        return uint8(_decimals);
    }

    function asset() external view override returns (address) {
        return token;
    }

    /*//////////////////////////////////////////////////////////////
                      DEPOSIT/WITHDRAWAL LOGIC
  //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver)
        public
        override
        returns (uint256 shares)
    {
        (assets, shares) = _deposit(assets, receiver, msg.sender);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver)
        public
        override
        returns (uint256 assets)
    {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        (assets, shares) = _deposit(assets, receiver, msg.sender);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    // TODO: add allowance check to use owner argument
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        (uint256 _withdrawn, uint256 _burntShares) = _withdraw(
            assets,
            receiver,
            msg.sender
        );

        emit Withdraw(msg.sender, receiver, owner, _withdrawn, _burntShares);
        return _burntShares;
    }

    // TODO: add allowance check to use owner argument
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        (uint256 _withdrawn, uint256 _burntShares) = _withdraw(
            assets,
            receiver,
            msg.sender
        );

        emit Withdraw(msg.sender, receiver, owner, _withdrawn, _burntShares);
        return _withdrawn;
    }

    /*//////////////////////////////////////////////////////////////
                          ACCOUNTING LOGIC
  //////////////////////////////////////////////////////////////*/

    function totalAssets() public view override returns (uint256) {
        return yVault.totalAssets();
    }

    function convertToShares(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        return (assets * (10**_decimals)) / yVault.pricePerShare();
    }

    function convertToAssets(uint256 shares)
        public
        view
        override
        returns (uint256)
    {
        return (shares * yVault.pricePerShare()) / (10**_decimals);
    }

    function previewDeposit(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares)
        public
        view
        override
        returns (uint256)
    {
        return (shares * yVault.pricePerShare()) / (10**_decimals);
    }

    function previewWithdraw(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        return (assets * (10**_decimals)) / yVault.pricePerShare();
    }

    function previewRedeem(uint256 shares)
        public
        view
        override
        returns (uint256)
    {
        return (shares * yVault.pricePerShare()) / (10**_decimals);
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSIT/WITHDRAWAL LIMIT LOGIC
  //////////////////////////////////////////////////////////////*/

    function maxDeposit(address _account)
        public
        view
        override
        returns (uint256)
    {
        _account; // TODO can acc custom logic per depositor
        VaultAPI _bestVault = yVault;
        uint256 _totalAssets = _bestVault.totalAssets();
        uint256 _depositLimit = _bestVault.depositLimit();
        if (_totalAssets >= _depositLimit) return 0;
        return _depositLimit - _totalAssets;
    }

    function maxMint(address _account)
        external
        view
        override
        returns (uint256)
    {
        return convertToShares(maxDeposit(_account));
    }

    function maxWithdraw(address owner)
        external
        view
        override
        returns (uint256)
    {
        return convertToAssets(this.balanceOf(owner));
    }

    function maxRedeem(address owner) external view override returns (uint256) {
        return this.balanceOf(owner);
    }

    function _deposit(
        uint256 amount, // if `MAX_UINT256`, just deposit everything
        address receiver,
        address depositor
    ) internal returns (uint256 deposited, uint256 mintedShares) {
        VaultAPI _vault = yVault;
        IERC20 _token = IERC20(token);

        if (amount == type(uint256).max) {
            amount = Math.min(
                _token.balanceOf(depositor),
                _token.allowance(depositor, address(this))
            );
        }

        SafeERC20.safeTransferFrom(_token, depositor, address(this), amount);

        if (_token.allowance(address(this), address(_vault)) < amount) {
            _token.approve(address(_vault), 0); // Avoid issues with some tokens requiring 0
            _token.approve(address(_vault), type(uint256).max); // Vaults are trusted
        }

        // beforeDeposit custom logic

        // Depositing returns number of shares deposited
        // NOTE: Shortcut here is assuming the number of tokens deposited is equal to the
        //       number of shares credited, which helps avoid an occasional multiplication
        //       overflow if trying to adjust the number of shares by the share price.
        uint256 beforeBal = _token.balanceOf(address(this));

        mintedShares = _vault.deposit(amount, address(this));

        uint256 afterBal = _token.balanceOf(address(this));
        deposited = beforeBal - afterBal;

        // afterDeposit custom logic
        _mint(receiver, mintedShares);

        // `receiver` now has shares of `_vault` as balance, converted to `token` here
        // Issue a refund if not everything was deposited
        uint256 refundable = amount - deposited;
        if (refundable > 0)
            SafeERC20.safeTransfer(_token, depositor, refundable);
    }

    function _withdraw(
        uint256 amount, // if `MAX_UINT256`, just withdraw everything
        address receiver,
        address sender
    ) internal returns (uint256 withdrawn, uint256 burntShares) {
        VaultAPI _vault = yVault;

        // Start with the total shares that `sender` has
        // Limit by maximum withdrawal size from each vault
        uint256 availableShares = Math.min(
            this.balanceOf(sender),
            _vault.maxAvailableShares()
        );

        if (availableShares == 0) revert NoAvailableShares();

        uint256 estimatedMaxShares = (amount * 10**uint256(_vault.decimals())) /
            _vault.pricePerShare();

        if (estimatedMaxShares > availableShares)
            revert NotEnoughAvailableSharesForAmount();

        // beforeWithdraw custom logic

        // withdraw from vault and get total used shares
        uint256 beforeBal = _vault.balanceOf(address(this));
        withdrawn = _vault.withdraw(estimatedMaxShares, receiver);
        burntShares = beforeBal - _vault.balanceOf(address(this));
        uint256 unusedShares = estimatedMaxShares - burntShares;

        // afterWithdraw custom logic
        _burn(sender, estimatedMaxShares);

        // return unusedShares to sender
        if (unusedShares > 0)
            SafeERC20.safeTransfer(_vault, sender, unusedShares);
    }
}
