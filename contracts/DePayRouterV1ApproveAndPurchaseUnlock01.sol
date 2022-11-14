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
  struct UnlockPurchase {
    bytes _calldata;
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

    // Call the smart contract which is receiver of the payment.
    {
      UnlockPurchase memory purchase;
      {
        purchase._calldata = abi.encodePacked(data[1]);
      }

      if(path[path.length-1] == NATIVE) {
        // Make sure to send the NATIVE along with the call in case of sending NATIVE.
        {
          (bool success, bytes memory returnData) = addresses[1].call{value: amounts[1]}(
            purchase._calldata
          );
          Helper.verifyCallResult(success, returnData, "Calling smart contract payment receiver failed!");
        }
      } else {
        {
          (bool success, bytes memory returnData) = addresses[1].call(
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
