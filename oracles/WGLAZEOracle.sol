// SPDX-License-Identifier: AGPL-3.0-only
// Using the same Copyleft License as in the original Repository
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "../interfaces/IOracle.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Factory.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";
import "../libraries/FixedPoint.sol";

// solhint-disable not-rely-on-time

// adapted from https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleSlidingWindowOracle.sol
interface IAggregator {
    function latestAnswer() external view returns (int256 answer);
}

interface IWGLAZE {
    function GLAZETowGLZAE( uint256 _amount ) external view returns ( uint256 );
}

contract WGLAZEOracle is IOracle {
    using FixedPoint for *;
    using BoringMath for uint256;
    uint256 public constant PERIOD = 10 minutes;

    IAggregator public constant MIM_USD = IAggregator(0x54EdAB30a7134A16a54218AE64C73e1DAf48a8Fb);
    IUniswapV2Pair public constant MIM_ICY = IUniswapV2Pair(0x453B5415Fe883f15686A5fF2aC6FF35ca6702628);
    IWGLAZE public constant WGLAZE = IWGLAZE(0x80277a98bD53AA835Ec4Cb7aEDF04Ac8fBac5E3C);

    struct PairInfo {
        uint256 priceCumulativeLast;
        uint32 blockTimestampLast;
        uint144 priceAverage;
    }

    PairInfo public pairInfo;
    function _get(uint256 blockTimestamp) public view returns (uint256) {
        uint256 priceCumulative = MIM_ICY.price1CumulativeLast();

        // if time has elapsed since the last update on the MIM_ICY, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(MIM_ICY).getReserves();
        priceCumulative += uint256(FixedPoint.fraction(reserve0, reserve1)._x) * (blockTimestamp - blockTimestampLast); // overflows ok

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        return priceCumulative;
    }

    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    /// @inheritdoc IOracle
    function get(bytes calldata data) external override returns (bool, uint256) {
        uint32 blockTimestamp = uint32(block.timestamp);
        if (pairInfo.blockTimestampLast == 0) {
            pairInfo.blockTimestampLast = blockTimestamp;
            pairInfo.priceCumulativeLast = _get(blockTimestamp);
            return (false, 0);
        }
        uint32 timeElapsed = blockTimestamp - pairInfo.blockTimestampLast; // overflow is desired
        if (timeElapsed < PERIOD) {
            return (true, pairInfo.priceAverage);
        }

        uint256 priceCumulative = _get(blockTimestamp);
        pairInfo.priceAverage = uint144(1e53 / (uint256(1e18).mul(uint256(FixedPoint
            .uq112x112(uint224((priceCumulative - pairInfo.priceCumulativeLast) / timeElapsed))
            .mul(1e18)
            .decode144())).mul(uint256(MIM_USD.latestAnswer())) / WGLAZE.GLAZETowGLZAE(1e9)));
        pairInfo.blockTimestampLast = blockTimestamp;
        pairInfo.priceCumulativeLast = priceCumulative;

        return (true, pairInfo.priceAverage);
    }

    // Check the last exchange rate without any state changes
    /// @inheritdoc IOracle
    function peek(bytes calldata data) public view override returns (bool, uint256) {
        uint32 blockTimestamp = uint32(block.timestamp);
        if (pairInfo.blockTimestampLast == 0) {
            return (false, 0);
        }
        uint32 timeElapsed = blockTimestamp - pairInfo.blockTimestampLast; // overflow is desired
        if (timeElapsed < PERIOD) {
            return (true, pairInfo.priceAverage);
        }

        uint256 priceCumulative = _get(blockTimestamp);
        uint144 priceAverage = uint144(1e53 / (uint256(1e18).mul(uint256(FixedPoint
            .uq112x112(uint224((priceCumulative - pairInfo.priceCumulativeLast) / timeElapsed))
            .mul(1e18)
            .decode144())).mul(uint256(MIM_USD.latestAnswer())) / WGLAZE.GLAZETowGLZAE(1e9)));

        return (true, priceAverage);
    }

    // Check the current spot exchange rate without any state changes
    /// @inheritdoc IOracle
    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        (uint256 reserve0, uint256 reserve1, ) = MIM_ICY.getReserves();
        rate = 1e53 / (uint256(1e18).mul(reserve0.mul(1e18) / reserve1).mul(uint256(MIM_USD.latestAnswer())) / WGLAZE.GLAZETowGLZAE(1e9));
    }

    /// @inheritdoc IOracle
    function name(bytes calldata) public view override returns (string memory) {
        return "WGLAZE TWAP";
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public view override returns (string memory) {
        return "WGLAZE";
    }
}