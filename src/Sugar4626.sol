// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC4626.sol";

contract Sugar4626 is Ownable {
    address public immutable vault;
    address public immutable yieldToken;

    constructor(address _yieldToken, address _yVault) {
        // if vault is not 0x0 means yieldToken is backed by a yvault
        vault = _yVault;
        yieldToken = _yieldToken;
    }
}
