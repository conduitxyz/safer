// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console2.sol";
import "forge-std/StdJson.sol";
import "forge-std/Script.sol";

/**
 * Struct representing a single transaction in the batch
 * operation: 0 for call, 1 for delegatecall
 * to: target address
 * value: amount of ETH to send
 * data: transaction data
 */
struct MetaTransaction {
    uint8 operation;
    address to;
    uint256 value;
    bytes data;
}

/**
 * Encodes the transaction as packed bytes of:
 * - `operation` as a `uint8` with `0` for a `call` or `1` for a `delegatecall` (=> 1 byte),
 * - `to` as an `address` (=> 20 bytes),
 * - `value` as a `uint256` (=> 32 bytes),
 * -  length of `data` as a `uint256` (=> 32 bytes),
 * - `data` as `bytes`.
 */
contract PrepareMultiSendTx is Script {
    using stdJson for string;

    string internal ROOT = vm.projectRoot();
    string internal BATCH_FILE = string.concat(ROOT, "/data/batch.json");
    string internal TX_FILE = string.concat(ROOT, "/data/tx.json");

    function run() public {
        // Read the multisend contract address from environment
        address multiSendAddr = vm.envAddress("MULTI_SEND_ADDR");
        
        // Read the batch file
        string memory json = vm.readFile(BATCH_FILE);
        uint batchLength = 2; // Update this if your batch.json changes
        
        bytes memory encodedTxs;
        
        for (uint i = 0; i < batchLength; i++) {
            string memory prefix = string(abi.encodePacked("[", vm.toString(i), "]"));
            uint8 operation = uint8(json.readUint(string.concat(prefix, ".operation")));
            address to = json.readAddress(string.concat(prefix, ".to"));
            uint256 value = json.readUint(string.concat(prefix, ".value"));
            bytes memory data = json.readBytes(string.concat(prefix, ".data"));
            
            console2.log("Transaction", i, ":");
            console2.log("  operation:", operation);
            console2.log("  to:", to);
            console2.log("  value:", value);
            console2.log("  data length:", data.length);
            console2.log("  data:");
            console2.logBytes(data);
            
            MetaTransaction memory transaction = MetaTransaction({
                operation: operation,
                to: to,
                value: value,
                data: data
            });
            
            bytes memory encodedTx = encodePacked(transaction);
            encodedTxs = abi.encodePacked(encodedTxs, encodedTx);
        }
        
        // Create the final transaction to the multisend contract
        string memory objectKey = "output";
        string memory jsonOutput;
        jsonOutput = vm.serializeAddress(objectKey, "to", multiSendAddr);
        jsonOutput = vm.serializeUint(objectKey, "value", 0);
        jsonOutput = vm.serializeBytes(objectKey, "data", abi.encodeWithSignature("multiSend(bytes)", encodedTxs));
        jsonOutput = vm.serializeUint(objectKey, "operation", 1); // delegatecall
        jsonOutput = vm.serializeUint(objectKey, "safeTxGas", 0);
        jsonOutput = vm.serializeUint(objectKey, "baseGas", 0);
        jsonOutput = vm.serializeUint(objectKey, "gasPrice", 0);
        jsonOutput = vm.serializeAddress(objectKey, "gasToken", address(0));
        jsonOutput = vm.serializeAddress(objectKey, "refundReceiver", address(0));
        
        // Write the output to tx.json
        vm.writeJson(jsonOutput, TX_FILE);
        
        console2.log("Batch encoded successfully! File location:", TX_FILE);
    }
    
    /**
     * Encodes a MetaTransaction using packed encoding
     */
    function encodePacked(MetaTransaction memory transaction) internal pure returns (bytes memory) {
        return abi.encodePacked(
            transaction.operation,
            transaction.to,
            transaction.value,
            transaction.data.length,
            transaction.data
        );
    }
}
