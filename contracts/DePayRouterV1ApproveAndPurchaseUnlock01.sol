// SPDX-License-Identifier: MIT

pragma solidity >=0.8.6 <0.9.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './libraries/Helper.sol';
import "hardhat/console.sol";

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
    uint256[1] _values;
    address[1] _recipients;
    address[1] _referrers;
    address[1] _managers;
    bytes[1] _data;
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

    console.log('sig', data[0]);
    console.log('calldata', data[1]);

    // Call the smart contract which is receiver of the payment.
    {
      UnlockCall memory purchase;
      {
        purchase._sig = data[0];
        purchase._calldata = bytes(data[1]);
        purchase._lockAddress = addresses[0];
        purchase._amount = amounts[0];
      }

      // decode
      // console.log('sig', purchase._sig);
      // console.log('calldata', string(purchase._calldata));
      console.log('contract address', purchase._lockAddress);
      console.log('value', purchase._amount);
      
      if(path[path.length-1] == NATIVE) {
        console.log('native');
        // Make sure to send the NATIVE along with the call in case of sending NATIVE.
        {
          (bool success, bytes memory returnData) = purchase._lockAddress.call{value: purchase._amount}(
            purchase._calldata
          );
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
