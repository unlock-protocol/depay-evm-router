// SPDX-License-Identifier: MIT

// used for running automated hardhat tests

import '../libraries/Helper.sol';
import "hardhat/console.sol";
pragma solidity >=0.8.6 <0.9.0;

contract TestUnlock  {

  event UnlockEvent(
    address recipient
  );

  function purchase(
    uint256[1] memory _values,
    address[1] memory _recipients,
    address[1] memory _referrers,
    address[1] memory _keyManagers,
    bytes[1] memory _data
  ) external payable returns (uint) {
    console.log("CALL");
    console.log(_values.length);
    console.log(_recipients.length);
    console.log(_referrers.length);
    console.log(_keyManagers.length);
    console.log(_data.length);

    emit UnlockEvent(_recipients[0]);
    return(_values[0]);
  }

  function hello() public  {
    console.log('hello');
  }
}
