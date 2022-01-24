// SPDX-License-Identifier: MIT

// North

// Special thanks to:
// @BoringCrypto for his great libraries

pragma solidity 0.6.12;
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/ERC20.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";

/// @title North
/// @author 0xMerlin
/// @dev This contract allows contract calls to any contract (except BentoBox)
/// from arbitrary callers thus, don't trust calls from this contract in any circumstances.
contract North is ERC20, BoringOwnable {
    using BoringMath for uint256;
    // ERC20 'variables'
    string public constant symbol = "NORTH";
    string public constant name = "North Token";
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;
    uint256 public constant MAX_SUPPLY = 273150000 * 1e18;

    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "NORTH: no mint to zero address");
        require(MAX_SUPPLY >= totalSupply.add(amount), "NORTH: Don't go over MAX");

        totalSupply = totalSupply + amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}
