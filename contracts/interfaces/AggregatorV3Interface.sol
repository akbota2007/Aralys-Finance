// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
<<<<<<< HEAD:contracts/interfaces/AggregatorV3Interface.sol
    function description() external view returns (string memory);
    function version() external view returns (uint256);
=======

    function description() external view returns (string memory);

    function version() external view returns (uint256);

>>>>>>> 59d5972 (test(vault): add YieldVaultV2 upgrade tests, fix V2 constructor):aralys-finance/contracts/interfaces/AggregatorV3Interface.sol
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
<<<<<<< HEAD:contracts/interfaces/AggregatorV3Interface.sol
=======

>>>>>>> 59d5972 (test(vault): add YieldVaultV2 upgrade tests, fix V2 constructor):aralys-finance/contracts/interfaces/AggregatorV3Interface.sol
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
<<<<<<< HEAD:contracts/interfaces/AggregatorV3Interface.sol
}
=======
}
>>>>>>> 59d5972 (test(vault): add YieldVaultV2 upgrade tests, fix V2 constructor):aralys-finance/contracts/interfaces/AggregatorV3Interface.sol
