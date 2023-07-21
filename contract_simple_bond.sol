pragma solidity ^0.8.0;

contract PlainVanillaBond {
    // Contract variables
    address private issuer; // The address of the issuer of the bond
    uint private maturityDate; // Unix timestamp representing the maturity date of the bond
    uint private couponRate; // The interest rate (coupon) of the bond in percentage
    uint private couponFrequency; // The frequency at which coupons are paid (e.g., semi-annual)
    uint public nominal_value; // The nominal value of each bond
    bool private isLiquidated; // A flag indicating if the bond has been liquidated
    address[] private allholderscupons; // An array storing addresses of all bond holders
    mapping(address => bool) private kycStatus; // A mapping to track the KYC status of bond holders
    mapping(address => uint256) private balancescupons; // A mapping to store the number of coupons each bond holder holds

    event Transfer(address indexed from, address indexed to, uint256 value); // Event to track the transfer of coupons

    modifier onlyIssuer() {
        require(msg.sender == issuer, "Only the issuer can call this function."); // Modifier to allow only the issuer to call certain functions
        _;
    }

    modifier kycVerified(address user) {
        require(kycStatus[user], "KYC verification is required."); // Modifier to require KYC verification for specific functions
        _;
    }

    constructor() {
        issuer = msg.sender;
        maturityDate = block.timestamp + (2*60*60*24*365); // Set the maturity date 2 years
        couponRate = 5; // Set the coupon rate to 5% (can be adjusted)
        couponFrequency = 2; // Set the coupon frequency to 2 (e.g., semi-annual payments)
        nominal_value = 5; // Set the nominal value of each bond to 5 (can be adjusted)
        isLiquidated = false; // Set the liquidation flag to false
    }



    // Getter and setter functions 
    function getKYCStatus(address user) external view onlyIssuer returns (bool status) {
        return kycStatus[user];
    }

    function setKYCStatus(address user, bool status) external onlyIssuer {
        kycStatus[user] = status; // Set the KYC status of the bond holder
    }

    function getallHolderscupons() external view onlyIssuer returns (address[] memory) {
        return allholderscupons; // Get the list of all bond holders
    }

    function remove(address removed) internal {
        for (uint256 i = 0; i <= allholderscupons.length; i++) {
            if (removed == allholderscupons[i]) {
                allholderscupons[i] = allholderscupons[allholderscupons.length - 1]; // Move the last element to the position of the removed element
                allholderscupons.pop(); // Remove the last element from the array
            }
        }
    }




    // Function to buy tokens (coupons) with ether
    function buyTokens() external payable kycVerified(msg.sender) {
        require(!isLiquidated, "The bond has been liquidated, token purchase is not allowed.");
        require(block.timestamp < maturityDate, "Maturity date has passed.");
        require(msg.value > 0, "Invalid amount of ether sent.");

        // Calculate the number of coupons that will be given to the buyer
        uint256 cuponsAmount = (msg.value) / nominal_value;

        // Verify that the contract has enough coupons to sell
        require(balancescupons[issuer] >= cuponsAmount, "Insufficient tokens to sell.");

        // Transfer the coupons to the buyer
        balancescupons[msg.sender] += cuponsAmount;
        balancescupons[issuer] -= cuponsAmount;
        allholderscupons.push(msg.sender); // Add the bond holder to the list of all bond holders

        // Emit the transfer event to record the token purchase
        emit Transfer(issuer, msg.sender, cuponsAmount);
    }


    //BOND FUNCTIONS

    // Function to redeem coupons
    function redeemCoupon() external onlyIssuer kycVerified(issuer) {
        require(!isLiquidated, "The bond has been liquidated, coupon redemption is not allowed.");
        require(block.timestamp < maturityDate, "Maturity date has passed.");

        // Pay coupons to all bond holders
        for (uint256 i = 0; i < allholderscupons.length; i++) {
            address bondHolder = allholderscupons[i];
            if (kycStatus[bondHolder]) {
                uint256 couponAmount = (balancescupons[bondHolder] * nominal_value * couponRate) / (couponFrequency * 100);
                paycrypto(payable(bondHolder), couponAmount);
            }
        }

        // Check if the maturity date has been reached during the coupon payment
        if (block.timestamp >= maturityDate) {
            liquidateBond();
            isLiquidated = true;
        }
    }

    // Function to check if the maturity date has been reached
    function checkBond() external onlyIssuer view returns(string memory state){
        
        if (block.timestamp >= maturityDate){
            state="Maturity date has not been reached.";
        }
        else {
            if (!isLiquidated){
            state="The bond has already been liquidated.";
            }
            else {
            state="This bond is still available";
            }
        }
        return (state);
    }

    // Function to liquidate the bond and pay out the remaining coupons
    function liquidateBond() internal {
        require(!isLiquidated, "The bond has already been liquidated.");

        for (uint256 i = 0; i < allholderscupons.length; i++) {
            address bondHolder = allholderscupons[i];

            if (kycStatus[bondHolder] && balancescupons[bondHolder] > 0) {
                uint256 initialpayment = (balancescupons[bondHolder] * nominal_value);
                paycrypto(payable(bondHolder), initialpayment);
            }
        }
        isLiquidated = true;
    }



    //TRANSFER FUNCTIONS

    // Function to transfer coupons between bond holders
    function transfer(address to, uint256 amount) external kycVerified(msg.sender) kycVerified(to) {
        require(!isLiquidated, "The bond has been liquidated, transfers are not allowed.");
        _transfer(msg.sender, to, amount);

        emit Transfer(msg.sender, to, amount);
    }

    // Internal function to transfer coupons between bond holders
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Invalid sender address.");
        require(to != address(0), "Invalid recipient address.");
        require(amount > 0, "Invalid transfer amount.");

        // Verify that the sender has enough coupons to transfer
        require(balancescupons[from] >= amount, "Insufficient balance.");

        // Subtract the coupons from the sender
        balancescupons[from] -= amount;
        if (balancescupons[from] == 0) {
            remove(from); // Remove the sender from the list of bond holders if their coupon balance becomes zero
        }

        // Add the coupons to the recipient
        balancescupons[to] += amount;

        // Emit the transfer event to record the coupon transfer
        emit Transfer(from, to, amount);
    }

    // Internal function to make cryptocurrency payments
    function paycrypto(address payable recipient, uint256 amount) internal onlyIssuer {
        require(!isLiquidated, "The bond has been liquidated, payments are not allowed.");
        require(amount > 0, "Invalid amount.");

        // Verify that the contract has enough ether to make the payment
        require(address(this).balance >= amount, "Insufficient ether in the contract.");

        // Transfer the ether to the recipient
        recipient.transfer(amount);
    }
}

