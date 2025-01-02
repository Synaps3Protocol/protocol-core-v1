// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title MetricsOps
/// @notice Provides functionality to log metrics via events. This library enables
///         modular and reusable metric tracking across multiple contracts.
library MetricsOps {
    /// @notice Emitted when a metric is logged.
    /// @param metric The name of the metric being logged (e.g., "access_count").
    /// @param value The value associated with the metric.
    /// @param timestamp The timestamp when the metric was logged.
    /// @param context Additional context or data associated with the metric.
    ///        This could include asset IDs, policy addresses, or other encoded data.
    event MetricLogged(string indexed metric, uint256 value, uint256 timestamp, bytes context);

    /// @notice Logs a metric with additional context information.
    /// @param metric The name of the metric to log (e.g., "user_interactions").
    /// @param value The value associated with the metric (e.g., a count or amount).
    /// @param context Encoded data providing additional context for the metric.
    ///        This can include asset IDs, user addresses, or policy-related data.
    ///        Use `abi.encode` to prepare this context.
    function logMetricWithContext(string memory metric, uint256 value, bytes memory context) internal {
        // Emit the event to log the metric with all relevant data.
        emit MetricLogged(metric, value, block.timestamp, context);
    }
}
