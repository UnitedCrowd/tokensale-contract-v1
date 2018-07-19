pragma solidity ^0.4.18;


import './RefundVault.sol';
import './FinalizableCrowdsale.sol';
import './SafeMath.sol';
import './UnitedSmartToken.sol';


contract UnitedCrowdsale is FinalizableCrowdsale {

    // =================================================================================================================
    //                                      Constants
    // =================================================================================================================
    // Max amount of known addresses of which will get Unitedcrowd by 'Grant' method.
    //
    // grantees addresses will be Unitedcrowd wallets addresses.
    // these wallets will contain Unitedcrowd tokens that will be used for 2 purposes only -
    // 1. Unitedcrowd tokens against raised fiat money
    // 2. Unitedcrowd tokens for presale bonus.
    // we Unitedcrowd the value to 10 (and not to 2) because we want to allow some flexibility for cases like fiat money that is raised close to the crowdsale.
    // we limit the value to 10 (and not larger) to limit the run time of the function that process the grantees array.


    uint8 public constant MAX_TOKEN_GRANTEES = 100;

    // UCT to ETH base rate
    uint256 public constant EXCHANGE_RATE = 500;

    // Refund division rate
    uint256 public constant REFUND_DIVISION_RATE = 2;

    // =================================================================================================================
    //                                      Modifiers
    // =================================================================================================================

    /**
     * @dev Throws if called not during the crowdsale time frame
     */
    modifier onlyWhileSale() {
        require(isActive());
        _;
    }

    // =================================================================================================================
    //                                      Members
    // =================================================================================================================

    // wallets address for 60% of Unitedcrowd allocation
    address public walletTeam;   //10% of the total number of UTC tokens will be allocated to the team

    address public walletBounties;  //5% of the total number of UTC tokens will be allocated to professional fees and Bounties
    address public walletReserve;   //35% of the total number of UTC tokens will be allocated to Unitedcrowd and as a reserve for the company to be used for future strategic plans for the created ecosystem

    // Funds collected outside the crowdsale in wei
    uint256 public fiatRaisedConvertedToWei;

    //Grantees - used for non-ether and presale bonus token generation
    address[] public presaleGranteesMapKeys;
    mapping (address => uint256) public presaleGranteesMap;  //address=>wei token amount

    // The refund vault
    RefundVault public refundVault;

    // =================================================================================================================
    //                                      Events
    // =================================================================================================================
    event GrantAdded(address indexed _grantee, uint256 _amount);

    event GrantUpdated(address indexed _grantee, uint256 _oldAmount, uint256 _newAmount);

    event GrantDeleted(address indexed _grantee, uint256 _hadAmount);

    event FiatRaisedUpdated(address indexed _address, uint256 _fiatRaised);

    event TokenPurchaseWithGuarantee(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    // =================================================================================================================
    //                                      Constructors
    // =================================================================================================================

    function UnitedCrowdsale(uint256 _startTime,
    uint256 _endTime,
    address _wallet,
    address _walletTeam,

    address _walletBounties,
    address _walletReserve,
    UnitedSmartToken _unitedSmartToken,
    RefundVault _refundVault)
    public Crowdsale(_startTime, _endTime, EXCHANGE_RATE, _wallet, _unitedSmartToken) {
        require(_walletTeam != address(0));
        require(_walletBounties != address(0));
        require(_walletReserve != address(0));
        require(_unitedSmartToken != address(0));
        require(_refundVault != address(0));

        walletTeam = _walletTeam;

        walletBounties = _walletBounties;
        walletReserve = _walletReserve;

        token = _unitedSmartToken;
        refundVault  = _refundVault;
    }

    // =================================================================================================================
    //                                      Impl Crowdsale
    // =================================================================================================================

    // @return the rate in UTC per 1 ETH according to the time of the tx and the UCT pricing program.
    // @Override
    function getRate() public view returns (uint256) {
        if (now < (startTime.add(24 hours))) {return 1000;}
        if (now < (startTime.add(2 days))) {return 950;}
        if (now < (startTime.add(3 days))) {return 900;}
        if (now < (startTime.add(4 days))) {return 855;}
        if (now < (startTime.add(5 days))) {return 810;}
    

        return rate;
    }

    // =================================================================================================================
    //                                      Impl FinalizableCrowdsale
    // =================================================================================================================

    //@Override
    function finalization() internal onlyOwner {
        super.finalization();

        // granting bonuses for the pre crowdsale grantees:
        for (uint256 i = 0; i < presaleGranteesMapKeys.length; i++) {
            token.issue(presaleGranteesMapKeys[i], presaleGranteesMap[presaleGranteesMapKeys[i]]);
        }

        // Adding 60% of the total token supply (40% were generated during the crowdsale)
        // 40 * 2.5 = 100
        uint256 newTotalSupply = token.totalSupply().mul(250).div(100);

        // 10% of the total number of UCT tokens will be allocated to the team
        token.issue(walletTeam, newTotalSupply.mul(10).div(100));


        // 5% of the total number of UCT tokens will be allocated to professional fees and Bounties
        token.issue(walletBounties, newTotalSupply.mul(5).div(100));

        // 35% of the total number of UCT tokens will be allocated to United LABS,
        // and as a reserve for the company to be used for future strategic plans for the created ecosystem
        token.issue(walletReserve, newTotalSupply.mul(35).div(100));

        // Re-enable transfers after the token sale.
        token.disableTransfers(false);

        // Re-enable destroy function after the token sale.
        token.setDestroyEnabled(true);

        // Enable ETH refunds and token claim.
        refundVault.enableRefunds();

        // transfer token ownership to crowdsale owner
        token.transferOwnership(owner);

        // transfer refundVault ownership to crowdsale owner
        refundVault.transferOwnership(owner);
    }

    // =================================================================================================================
    //                                      Public Methods
    // =================================================================================================================
    // @return the total funds collected in wei(ETH and none ETH).
    function getTotalFundsRaised() public view returns (uint256) {
        return fiatRaisedConvertedToWei.add(weiRaised);
    }

    // @return true if the crowdsale is active, hence users can buy tokens
    function isActive() public view returns (bool) {
        return now >= startTime && now < endTime;
    }

    // =================================================================================================================
    //                                      External Methods
    // =================================================================================================================
    // @dev Adds/Updates address and token allocation for token grants.
    // Granted tokens are allocated to non-ether, presale, buyers.
    // @param _grantee address The address of the token grantee.
    // @param _value uint256 The value of the grant in wei token. this time for new user generation

    function addUpdateGrantee(address _grantee, uint256 _value) external onlyOwner onlyWhileSale{
        require(_grantee != address(0));
        require(_value > 0);

        // Adding new key if not present:
        if (presaleGranteesMap[_grantee] == 0) {
            require(presaleGranteesMapKeys.length < MAX_TOKEN_GRANTEES);
            presaleGranteesMapKeys.push(_grantee);
            GrantAdded(_grantee, _value);
        }
        else {
            GrantUpdated(_grantee, presaleGranteesMap[_grantee], _value);
        }

        presaleGranteesMap[_grantee] = _value;
    }

    // @dev deletes entries from the grants list.
    // @param _grantee address The address of the token grantee.
    function deleteGrantee(address _grantee) external onlyOwner onlyWhileSale {
        require(_grantee != address(0));
        require(presaleGranteesMap[_grantee] != 0);

        //delete from the map:
        delete presaleGranteesMap[_grantee];

        //delete from the array (keys):
        uint256 index;
        for (uint256 i = 0; i < presaleGranteesMapKeys.length; i++) {
            if (presaleGranteesMapKeys[i] == _grantee) {
                index = i;
                break;
            }
        }
        presaleGranteesMapKeys[index] = presaleGranteesMapKeys[presaleGranteesMapKeys.length - 1];
        delete presaleGranteesMapKeys[presaleGranteesMapKeys.length - 1];
        presaleGranteesMapKeys.length--;

        GrantDeleted(_grantee, presaleGranteesMap[_grantee]);
    }

    // @dev Set funds collected outside the crowdsale in wei.
    //  note: we not to use accumulator to allow flexibility in case of humane mistakes.
    // funds are converted to wei using the market conversion rate of USD\ETH on the day on the purchase.
    // @param _fiatRaisedConvertedToWei number of none eth raised.
    function setFiatRaisedConvertedToWei(uint256 _fiatRaisedConvertedToWei) external onlyOwner onlyWhileSale {
        fiatRaisedConvertedToWei = _fiatRaisedConvertedToWei;
        FiatRaisedUpdated(msg.sender, fiatRaisedConvertedToWei);
    }

    /// @dev Accepts new ownership on behalf of the UnitedCrowdsale contract. This can be used, by the token sale
    /// contract itself to claim back ownership of the UnitedSmartToken contract.
    function claimTokenOwnership() external onlyOwner {
        token.claimOwnership();
    }

    /// @dev Accepts new ownership on behalf of the UnitedCrowdsale contract. This can be used, by the token sale
    /// contract itself to claim back ownership of the refundVault contract.
    function claimRefundVaultOwnership() external onlyOwner {
        refundVault.claimOwnership();
    }

    // @dev Buy tokes with guarantee
    function buyTokensWithGuarantee() public payable {
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // calculate token amount to be created
        uint256 tokens = weiAmount.mul(getRate());
        tokens = tokens.div(REFUND_DIVISION_RATE);

        // update state
        weiRaised = weiRaised.add(weiAmount);

        token.issue(address(refundVault), tokens);

        refundVault.deposit.value(msg.value)(msg.sender, tokens);

        TokenPurchaseWithGuarantee(msg.sender, address(refundVault), weiAmount, tokens);

    }
}
