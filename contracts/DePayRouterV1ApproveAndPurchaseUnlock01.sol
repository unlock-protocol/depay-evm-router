// SPDX-License-Identifier: MIT

pragma solidity >=0.8.6 <0.9.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './libraries/Helper.sol';
import "hardhat/console.sol";

import './test/ITestUnlock.sol';

contract DePayRouterV1ApproveAndCallContractAmountsAddressesAddressesAddressesBytes {

  // Address representating NATIVE currency
  address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  // Indicates that this plugin requires delegate call
  bool public immutable delegate = true;

  // Prepare unlock purchase via struct
  // to save local variable slots
  struct UnlockCall {
    address _lockAddress;
    uint _amount;
    string _sig;
    bytes _calldata;
  }

  struct UnlockPurchase {
    uint256[] _values;
    address[] _recipients;
    address[] _referrers;
    address[] _managers;
    bytes[] _data;
  }

  // Call another smart contract to deposit an amount for a given address while making sure the amount passed to the contract is approved.
  //
  // Approves the amount at index 1 of amounts (amounts[1])
  // for the token at the last position of path (path[path.length-1])
  // to be used by the smart contract at index 1 of addresses (addresses[1]).
  // 
  // Afterwards, calls the smart contract at index 1 of addresses (addresses[1]),
  // passing the address at index 0 of addresses (addresses[0])
  // and passing the amount at index 1 of amounts (amounts[1])
  // to the method with the signature provided in data at index 0 (data[0]).
  
  function getSig(bytes memory _data) 
        private 
        pure 
        returns(
            bytes4 sig
        ) 
    {
        assembly {
            sig := mload(add(_data, 32))
        }
    }

  // data[0] is the method signature
  // data[1] is the encoded call data
  function execute(
    address[] calldata path,
    uint[] calldata amounts,
    address[] calldata addresses,
    string[] calldata data
  ) external payable returns(bool) {

    // Approve the amount that needs to be passed on to the smart contract.
    if(path[path.length-1] != NATIVE) {
      Helper.safeApprove(
        path[path.length-1],
        addresses[1],
        amounts[1]
      );
    }

    // Call the smart contract which is receiver of the payment.
    {
      UnlockCall memory purchase;
      {
        purchase._sig = data[0];
        purchase._calldata = bytes(data[1]);
        purchase._lockAddress = addresses[0];
        purchase._amount = amounts[1];
      }
      // console.log(data[1]);
      // console.log('purchase._lockAddress', purchase._lockAddress);
      // console.log('purchase._sig', purchase._sig);
      // console.log('purchase._calldata', string(purchase._calldata));
      // console.log('purchase._amount', purchase._amount);
      // console.log('amountIn', amounts[0]);

      // require(getSig(abi.encode(data[1])) == 0x33818997, 'wrong abi.encode getSig');
      // require(getSig((bytes(data[1]))) == 0x33818997, 'wrong bytes getSig');
      // require(getSig(purchase._calldata) == 0x33818997, 'wrong getSig');
      // require(bytes4(bytes(data[1])[4:]) == 0x33818997, 'wrong bytes(data[1])[4:]');

      // (address[] memory hello,,,,) = abi.decode(
      //   bytes(data[1])[4:], 
      //   (address[], uint[], address[], string[], bytes[]));
      // // console.log('sig', string(abi.encodePacked(sig)));
      // console.log('hello[0]', hello[0]);
      
      // console.log(recipient);

      // decode
      if(path[path.length-1] == NATIVE) {
        console.log('native');
        // Make sure to send the NATIVE along with the call in case of sending NATIVE.
        {
          console.log('purchase._calldata', string(purchase._calldata));
          ITestUnlock(purchase._lockAddress).hello();

          ITestUnlock(purchase._lockAddress).purchase(
            [uint(0)],
            [address(0)],
            [address(0)], 
            [address(0)],
            [bytes('')]
          );

          bytes memory calldata2 = abi.encodeWithSignature(
            "purchase(uint256[1],address[1],address[1],address[1],bytes[1])", 
            [uint(0)],[address(0)],[address(0)], [address(0)],[bytes('')]
          );

          console.logBytes(bytes(data[1])); // ethers encodeFunctionData
          console.logBytes(calldata2);

          //   bytes4(keccak256()), );

          (bool success, bytes memory returnData) = purchase._lockAddress.call(
            // calldata2
            bytes(data[1])
            // purchase._calldata
            // abi.encodeWithSignature(purchase._sig, purchase._calldata[:4])
          );
          console.log(success, string(abi.encodePacked(returnData)));
          Helper.verifyCallResult(success, returnData, "Calling smart contract payment receiver failed!");
        }
      } else {
        console.log('not native');
        {
          (bool success, bytes memory returnData) = purchase._lockAddress.call(
            purchase._calldata
          );
          Helper.verifyCallResult(success, returnData, "Calling smart contract payment receiver failed!");
        }
      }
    }

    // Reset allowance after paying to the smart contract
    if(path[path.length-1] != NATIVE && IERC20(path[path.length-1]).allowance(address(this), addresses[1]) > 0) {
      Helper.safeApprove(
        path[path.length-1],
        addresses[1],
        0
      ); 
    }

    return true;
  }
}
