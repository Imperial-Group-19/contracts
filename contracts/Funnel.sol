//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

//=====================--------- DEPLOYMENT TO-DOS:  ----------=====================

import "@openzeppelin/contracts/access/Ownable.sol";
// a Contract module that provides basic access control mechanism, where a specific
// account is granted exclusive access to specific functions. (see onlyStoreOwner modifier)
import "./EnumProductTypeDeclaration.sol";
// Import enum type that maps different product types to fixed constants.
import "./ABDKMathQuad.sol"; 
// For safe math operations.

//=====================--------- ITERATION TO-DOS:  ----------=====================
//TODO: Implement more tests.
//TODO: Deploy contract using OpenZepp Proxy Pattern.


contract Funnel is Ownable {
    //=====================--------- EVENTS  ----------=====================

    event PaymentMade(
        address customer,
        address storeAddress,
        string[] productNames
    );
    event RefundMade(
        address customer,
        address storeAddress,
        string[] productNames
    );

    event ProductCreated(
        address storeAddress,
        string productName,
        uint256 price
    );
    event ProductUpdated(
        address storeAddress,
        string productName,
        uint256 newPrice
    );
    event ProductRemoved(address storeAddress, string productName);

    event StoreCreated(address storeAddress, address storeOwner);
    event StoreUpdated(address storeAddress, address newStoreAddress, address newStoreOwner);
    event StoreRemoved(address storeAddress);

    event AffiliateRegistered(address storeAddress, address affiliateAddress);

    //=====================--------- DATA STRUCTURES  ----------=====================

    struct Product {
        string _productName;
        ProductType _productType;
        uint256 _price;
    }

    struct Store {
        address _storeOwner;
        address payable _storeAddress;
        uint256 _storeTotalValue;
        Product[] _storeProducts;
        Affiliate[] _storeAffiliates;
        /* not using a mapping because structs with nested mapping cannot be returned
             in external functions */
        uint256 _commisionRate;
        bool _isStore;
    }

    struct Affiliate {
        address _affiliateAddress;
        uint256 _affiliateTotalValue;
    }

    //=====================--------- STATE VARIABLES ----------=====================

    uint256 private noOfStores;
    mapping(address => Store) private stores;
    mapping(address => bool) private isAdmin;

    //=====================--------- MODIFIERS ----------=====================

    modifier onlyStoreOwner(address storeAddress) {
        //check that caller is owner of specific store.
        require(
            stores[storeAddress]._storeOwner == msg.sender,
            "not store owner"
        );
        _;
    }

    //=====================--------- STORE FUNCTIONS ----------=====================
    constructor() {
        isAdmin[msg.sender] = true;
    }

    function totalStores() public view returns (uint256) {
        return noOfStores;
    }

    //TODO: implement transaction fee to deter spamming of this function.
    // possibly: https://stackoverflow.com/questions/70146314/how-do-i-charge-a-transaction-fee-when-a-function-in-my-contract-is-executed
    function registerStore(address payable storeAddress, uint commisionRate)
        external
        returns (uint256)
    {
        //CHECK if a store has already been created with storeAddress
        if ((stores[storeAddress]._isStore)) {
            //n.b. every possible key has a mapping by default.
            // see https://ethereum.stackexchange.com/questions/13021/how-can-you-figure-out-if-a-certain-key-exists-in-a-mapping-struct-defined-insi
            revert("There's already a store with that address.");
        }
        Store storage store = stores[storeAddress];
        store._storeOwner = msg.sender;
        store._storeAddress = storeAddress;
        store._storeTotalValue = 0;
        store._commisionRate = commisionRate;
        store._isStore = true;

        uint256 storeIndex = totalStores();
        noOfStores++;

        emit StoreCreated(storeAddress, msg.sender);

        return storeIndex;
    }

    function updateStoreAddress(
        address storeAddress,
        address payable newStoreAddress
    ) external onlyStoreOwner(storeAddress) {
        Store storage store = stores[newStoreAddress];
        store._storeAddress = newStoreAddress;
        store._storeTotalValue = stores[storeAddress]._storeTotalValue;
        store._storeOwner = stores[storeAddress]._storeOwner;
        store._storeProducts = stores[storeAddress]._storeProducts;
        store._storeAffiliates = stores[storeAddress]._storeAffiliates;
        store._isStore = true;

        delete stores[storeAddress];

        emit StoreUpdated(storeAddress, newStoreAddress, store._storeOwner);
    }

    function getStoreBalance(address storeAddress)
        external
        view
        returns (uint256)
    {
        if (!(stores[storeAddress]._isStore)) {
            revert("There's no store associated with that address");
        }
        return stores[storeAddress]._storeTotalValue;
    }

    function removeStore(address storeAddress) public {
        //currently only one admin
        //currently only they can remove store.
        delete stores[storeAddress];
        noOfStores--;
        emit StoreRemoved(storeAddress);
    }

    function getStore(address storeAddress)
        external
        view
        returns (Store memory)
    {
        return stores[storeAddress];
    }

    //=====================--------- TRANSACTIONAL FUNCTIONS ----------=====================

    function makePayment(
        address payable storeAddress,
        string[] memory productNames
    ) external payable {
        uint256 totalPrice;

        for (uint256 i; i < productNames.length; i++) {
            uint256 productIndex = getProductIndex(
                storeAddress,
                productNames[i]
            );
            uint256 price = stores[storeAddress]
                ._storeProducts[productIndex]
                ._price;
            totalPrice += price;
        }

        require(msg.value == totalPrice, "Pay the right price");

        storeAddress.transfer(msg.value);
        stores[storeAddress]._storeTotalValue += msg.value;

        emit PaymentMade(msg.sender, storeAddress, productNames);
    }

    //POSSIBLE SOURCES for affiliate payment splitting:
    // using https://ethereum.stackexchange.com/questions/114870/how-can-i-split-a-transaction-to-two-addresses-using-metamask
    // PaymentSplitter contract from OpenZepp is more robust but way more complicated.
    // there's also https://medium.com/coinmonks/implement-multi-send-on-ethereum-by-smart-contract-with-solidity-47e0bf82b60c
    //  as some middle ground.

    // using https://ethereum.stackexchange.com/questions/114870/how-can-i-split-a-transaction-to-two-addresses-using-metamask
    // PaymentSplitter contract from OpenZepp is more robust but way more complicated.
    // there's also https://medium.com/coinmonks/implement-multi-send-on-ethereum-by-smart-contract-with-solidity-47e0bf82b60c
    //  as some middle ground.

     //helper function for calculating amount owed to affiliate.
    // NOTE: the affiliate's comission will be rounded down if the result is a fractional number.
    //  see https://ethereum.stackexchange.com/questions/2987/how-can-i-represent-decimal-values-in-solidity
    function getAffiliateCut (uint256 sentAmount, uint256 commissionRate, uint256 base) public pure returns (uint) {
        return
            ABDKMathQuad.toUInt (
                ABDKMathQuad.div (
                    ABDKMathQuad.mul (
                    ABDKMathQuad.fromUInt (sentAmount),
                    ABDKMathQuad.fromUInt (commissionRate)
                    ),
                    ABDKMathQuad.fromUInt (base)
                )
            );
    }

    function makeSplitPayment(
        address payable storeAddress,
        address payable affiliateAddress,
        string[] memory productNames
    ) external payable {
        uint256 totalPrice;

        for (uint256 i; i < productNames.length; i++) {
            uint256 productIndex = getProductIndex(
                storeAddress,
                productNames[i]
            );
            uint256 price = stores[storeAddress]
                ._storeProducts[productIndex]
                ._price;
            totalPrice += price;
        }

        require(msg.value == totalPrice, "Pay the right price!");

        // Check affiliate address is linked to the store
        uint256 affiliateIndex = getAffiliateIndex(
            storeAddress,
            affiliateAddress
        );
        uint256 toAffiliate = (msg.value *
            stores[storeAddress]._commisionRate) / 100;
        uint256 toStore = msg.value - toAffiliate;
        storeAddress.transfer(toStore);
        affiliateAddress.transfer(toAffiliate);
        // Update balances for store and affiliate.
        stores[storeAddress]._storeTotalValue += toStore;
        stores[storeAddress]
            ._storeAffiliates[affiliateIndex]
            ._affiliateTotalValue += toAffiliate;

        emit PaymentMade(msg.sender, storeAddress, productNames);
    }

    function processRefund(
        address storeAddress,
        string[] memory productNames,
        address payable customer
    ) external payable onlyStoreOwner(storeAddress) {
        uint256 totalPrice;

        for (uint256 i; i < productNames.length; i++) {
            uint256 productIndex = getProductIndex(
                storeAddress,
                productNames[i]
            );
            uint256 price = stores[storeAddress]
                ._storeProducts[productIndex]
                ._price;
            totalPrice += price;
        }

        require(msg.value == totalPrice, "Incorrect refund amount");

        customer.transfer(msg.value);
        stores[storeAddress]._storeTotalValue -= msg.value;

        emit RefundMade(customer, storeAddress, productNames);
    }

    //=====================--------- PRODUCT FUNCTIONS ----------=====================
    //TODO: REFACTORING. There's a ton of duplication in these functions.
    function totalProducts(address storeAddress) public view returns (uint256) {
        return stores[storeAddress]._storeProducts.length;
    }

    function getProducts(address storeAddress)
        external
        view
        returns (Product[] memory)
    {
        return stores[storeAddress]._storeProducts;
    }

    function createProduct(
        address storeAddress,
        string memory productName,
        ProductType productType,
        uint256 price
    ) external onlyStoreOwner(storeAddress) {
        Product memory product = Product(productName, productType, price);

        stores[storeAddress]._storeProducts.push(product);

        emit ProductCreated(storeAddress, productName, price);
    }

    function removeProduct(address storeAddress, string memory productName)
        external
        onlyStoreOwner(storeAddress)
    {
        uint256 productIndex = getProductIndex(storeAddress, productName);
        Product[] storage products = stores[storeAddress]._storeProducts;

        products[productIndex] = products[products.length - 1];
        products.pop();

        emit ProductRemoved(storeAddress, productName);
    }

    //helper function for `removeProduct`
    function getProductIndex(address storeAddress, string memory productName)
        internal
        view
        returns (uint256)
    {
        for (uint256 i; i < stores[storeAddress]._storeProducts.length; i++) {
            if (
                keccak256(
                    bytes(stores[storeAddress]._storeProducts[i]._productName)
                ) == keccak256(bytes(productName))
            ) {
                return i;
            }
        }

        revert("Product not found in store");
    }

    function getProductPrice(address storeAddress, string memory productName)
        external
        view
        returns (uint256)
    {
        uint256 productIndex = getProductIndex(storeAddress, productName);
        return stores[storeAddress]._storeProducts[productIndex]._price;
    }

    function getProductType(address storeAddress, string memory productName)
        external
        view
        returns (ProductType)
    {
        uint256 productIndex = getProductIndex(storeAddress, productName);
        return stores[storeAddress]._storeProducts[productIndex]._productType;
    }

    function updateProductPrice(
        address storeAddress,
        string memory productName,
        uint256 price
    ) external onlyStoreOwner(storeAddress) {
        uint256 productIndex = getProductIndex(storeAddress, productName);
        stores[storeAddress]._storeProducts[productIndex]._price = price;

        emit ProductUpdated(storeAddress, productName, price);
    }

    //=====================--------- AFFILIATE FUNCTIONS ----------=====================

    function registerAffiliate(address affiliateAddress, address storeAddress)
        external
    {
        Affiliate memory affiliate = Affiliate(affiliateAddress, 0);
        stores[storeAddress]._storeAffiliates.push(affiliate);
        emit AffiliateRegistered(storeAddress, affiliateAddress);
    }

    function getAffiliateIndex(address storeAddress, address affiliateAddress)
        internal
        view
        returns (uint256)
    {
        for (uint256 i; i < stores[storeAddress]._storeAffiliates.length; i++) {
            if (
                stores[storeAddress]._storeAffiliates[i]._affiliateAddress ==
                affiliateAddress
            ) {
                return i;
            }
        }
        revert("Affiliate not found in store");
    }

    function getAffiliateBalance(address storeAddress, address affiliateAddress)
        external
        view
        returns (uint256)
    {
        if (!(stores[storeAddress]._isStore)) {
            revert("There's no store associated with that address");
        }
        uint256 affiliateIndex = getAffiliateIndex(
            storeAddress,
            affiliateAddress
        );
        return
            stores[storeAddress]
                ._storeAffiliates[affiliateIndex]
                ._affiliateTotalValue;
    }
}
