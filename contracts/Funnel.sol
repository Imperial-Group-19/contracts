//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

//=====================--------- DEPLOYMENT TO-DOS:  ----------=====================

//TODO: implement tests in Hardhat.
//TODO: DEPLOY CONTRACT USING PROXY PATTERN.

// Import Ownable from the OpenZeppelin Contracts library
import "@openzeppelin/contracts/access/Ownable.sol";

//=====================--------- ITERATION TO-DOS:  ----------=====================

contract Funnel is Ownable {
    //=====================--------- EVENTS  ----------=====================

    event PaymentMade(address customer, address storeAddress, string[] productNames);
    event RefundMade(address customer, address storeAddress, string[] productNames);

    event ProductCreated(address storeAddress, string productName, uint256 price);
    event ProductUpdated(address storeAddress, string productName, uint256 newPrice);
    event ProductRemoved(address storeAddress, string productName);

    event StoreCreated(address storeAddress, address storeOwner);
    event StoreUpdated(address storeAddress, address newStoreAddress);
    event StoreRemoved(address storeAddress);


    //=====================--------- DATA STRUCTURES  ----------=====================
    //TODO: update Product struct to capture the kind of product (e.g. 'main', or 'upsell')
    //      it is
    struct Product {
        string _productName;
        uint256 _price;
    }

    struct Store {
        address _storeOwner;
        address payable _storeAddress;
        uint256 _storeTotalValue;
        Product[] _storeProducts;
    }

    struct Affiliate {
        address payable _affiliateAddress;
        uint256 _commision;
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
    function registerStore(address payable storeAddress)
        external
        returns (uint256)
    {
        Store storage store = stores[storeAddress];
        store._storeOwner = msg.sender;
        store._storeAddress = storeAddress;
        store._storeTotalValue = 0;

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

        delete stores[storeAddress];

        emit StoreUpdated(storeAddress, newStoreAddress);
    }

    function removeStore(address storeAddress) public {
        //currently only one admin
        //currently only they can remove store.
        delete stores[storeAddress];

        emit StoreRemoved(storeAddress);
    }

    function getStore(address storeAddress) external view returns (Store memory) {
        return stores[storeAddress];
    }

    //=====================--------- TRANSACTIONAL FUNCTIONS ----------=====================

    function makePayment(
        address payable storeAddress,
        string[] memory productNames
    ) external payable {

        uint256 totalPrice;

        for (uint256 i; i<productNames.length; i++)
        {
            uint256 productIndex = getProductIndex(storeAddress, productNames[i]);
            uint256 price = stores[storeAddress]
                ._storeProducts[productIndex]
                ._price;
            totalPrice+=price;
        }
        
        require(msg.value == totalPrice, "Pay the right price");

        storeAddress.transfer(msg.value);
        stores[storeAddress]._storeTotalValue += msg.value;

        emit PaymentMade(msg.sender, storeAddress, productNames);
    }

    //TODO: implement protocol for affiliate payments

    function processRefund(address storeAddress, string[] memory productNames, address payable customer)
        external
        payable
        onlyStoreOwner(storeAddress)
    {   
        uint256 totalPrice;

        for (uint256 i; i<productNames.length; i++)
        {
            uint256 productIndex = getProductIndex(storeAddress, productNames[i]);
            uint256 price = stores[storeAddress]
                ._storeProducts[productIndex]
                ._price;
            totalPrice+=price;
        }

        require(msg.value == totalPrice, "Incorrect refund amount");

        customer.transfer(msg.value);
        stores[storeAddress]._storeTotalValue -= msg.value;

        emit RefundMade(customer, storeAddress, productNames);

    }

    //=====================--------- PRODUCT FUNCTIONS ----------=====================

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
        uint256 price
    ) external onlyStoreOwner(storeAddress) {
        Product memory product = Product(productName, price);

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

    function updateProductPrice(
        address storeAddress,
        string memory productName,
        uint256 price
    ) external onlyStoreOwner(storeAddress) {
        uint256 productIndex = getProductIndex(storeAddress, productName);
        stores[storeAddress]._storeProducts[productIndex]._price = price;

        emit ProductUpdated(storeAddress, productName, price);
    }
}
