pragma solidity ^0.4.18;


import './LimitedTransferSmartToken.sol';


/**
  A Token which is compatible and can mint new tokens and pause token-transfer functionality
*/

contract UnitedSmartToken is LimitedTransferSmartToken {

    // =================================================================================================================
    //          @@@@                               Members                        @@@@@
    // =================================================================================================================

    string public name = "Unitedcrowd";

    string public symbol = "UCT";

    uint8 public decimals = 18;

    // =================================================================================================================
    //                                         Constructor
    // =================================================================================================================

    function UnitedSmartToken() public {

        NewSmartToken(address(this));
    }
}
