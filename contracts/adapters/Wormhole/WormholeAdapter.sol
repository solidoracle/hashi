// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.17;

import "./IWormhole.sol";
import "../interfaces/IOracleAdapter.sol";

contract WormholeAdapter {
    IWormhole public wormhole;
    bytes32 public headerReporter;
    mapping(uint256 => mapping(uint256 => bytes32)) public headers;

    event HeaderStored(uint256 indexed blockNumber, bytes32 indexed blockHeader);

    error InvalidMessage(address emitter, VM vm, string reason);
    error InvalidChainId(address emitter, uint16 chainId);
    error InvalidReporter(address emitter, bytes32 reporter);

    constructor(IWormhole _wormhole, bytes32 _headerReporter) {
        wormhole = _wormhole;
        headerReporter = _headerReporter;
    }

    /// @dev Stores the block header for a given block.
    /// @param blockNumber Identifier for the block for which to set the header.
    /// @param chainId Identifier for the
    /// @param vm Structured data reflecting the content of the Wormhole Verified Action Approval.
    /// @notice Only callable by `wormhole` with a message passed from `headerReporter.
    function storeBlockHeader(uint256 blockNumber, uint16 chainId, VM memory vm) public {
        bytes32 currentBlockHeader = headers[uint256(chainId)][blockNumber];
        (VM memory _vm, bool valid, string memory reason) = wormhole.parseAndVerifyVM(abi.encode(vm));
        if (!valid) revert InvalidMessage(address(this), vm, reason);
        if (_vm.emitterChainId != chainId) revert InvalidChainId(address(this), _vm.emitterChainId);
        if (_vm.emitterAddress != headerReporter) revert InvalidReporter(address(this), _vm.emitterAddress);
        bytes32 newBlockHeader = abi.decode(_vm.payload, (bytes32));
        if (currentBlockHeader != newBlockHeader) {
            headers[uint256(chainId)][blockNumber] = newBlockHeader;
            emit HeaderStored(blockNumber, newBlockHeader);
        }
    }

    /// @dev Returns the block header for a given block, as reported by the Wormhole.
    /// @param blockNumber Identifier for the block to query.
    /// @return blockHeader Bytes32 block header reported by the oracle for the given block on the given chain.
    /// @notice MUST return bytes32(0) if the oracle has not yet reported a header for the given block.
    function getHeaderFromOracle(uint256 chainId, uint256 blockNumber) external view returns (bytes32 blockHeader) {
        blockHeader = headers[chainId][blockNumber];
    }
}
