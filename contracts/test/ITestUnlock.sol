// SPDX-License-Identifier: MIT

pragma solidity >=0.8.6 <0.9.0;

interface ITestUnlock  {

  event UnlockEvent(
    address recipient
  );

  function hello() external;

  function purchase(
    uint256[1] memory _values,
    address[1] memory _recipients,
    address[1] memory _referrers,
    address[1] memory _keyManagers,
    bytes[1] memory _data
  ) external payable returns (uint);
}
