//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

//=====================--------- DEPLOYMENT TO-DOS:  ----------=====================

//TODO: implement tests in Hardhat.
//TODO: DEPLOY CONTRACT USING PROXY PATTERN.

//=====================--------- ITERATION TO-DOS:  ----------=====================

//TODO: implement protocol for refunds
//TODO: implement protocol for affiliate payments
contract Funnel {
    //=====================--------- EVENTS  ----------=====================

    event PaymentMade(address from, address storeAddress, uint256 productId);

    //=====================--------- DATA STRUCTURES  ----------=====================
    struct Product {
        string _productName;
        uint256 _price;
    }
    //TODO: consider adding store name in bytes32?
    struct Store {
        //bytes32 _storeName;
        address payable _storeAddress;
        uint256 _storeTotalValue;
        Product[] storeProducts;
    }

    struct Affiliate {
        address payable _affiliateAddress;
        uint256 _commision;
    }

    //=====================--------- STATE VARIABLES ----------=====================

    uint256 private noOfStores;
    mapping(address => Store) private stores;
    mapping(address => bool) private isOwner;
    mapping(address => bool) private isAdmin;

    //=====================--------- MODIFIERS ----------=====================

    modifier onlyStoreOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "not admin");
        _;
    }

    //=====================--------- STORE FUNCTIONS ----------=====================
    constructor() public {
        isAdmin[msg.sender] = true;
    }

    function totalStores() public view returns (uint256) {
        return noOfStores;
    }

    function registerStore(address payable storeAddress)
        external
        returns (uint256)
    {
        Store storage store = stores[storeAddress];
        store._storeAddress = storeAddress;
        isOwner[storeAddress] = true;
        store._storeTotalValue = 0;

        uint256 storeIndex = totalStores();
        noOfStores++;

        return storeIndex;
    }

    function updateStoreAddress(
        address storeAddress,
        address payable newStoreAddress
    ) external onlyStoreOwner {
        Store storage store = stores[newStoreAddress];
        store._storeAddress = newStoreAddress;
        store._storeTotalValue = stores[storeAddress]._storeTotalValue;

        store.storeProducts = stores[storeAddress].storeProducts;

        delete stores[storeAddress];
    }

    //TODO: consider making the resetrictions on this function more robust: multiple admins required?
    function removeStore(address storeAddress) public onlyAdmin {
        //currently only one admin
        //currently only they can remove store.
        delete stores[storeAddress];
    }

    //=====================--------- TRANSACTIONAL FUNCTIONS ----------=====================

    function makePayment(address payable storeAddress, uint256 productId)
        external
        payable
        returns (bool)
    {
        Product memory product = stores[storeAddress].storeProducts[productId];
        uint256 price = product._price;
        require(msg.value == price, "Pay the right price");

        // address payable storeAddress = stores[storeAddress]._storeAddress;
        storeAddress.transfer(msg.value);
        stores[storeAddress]._storeTotalValue += msg.value;

        emit PaymentMade(msg.sender, storeAddress, productId);

        return true;
    }

    //=====================--------- PRODUCT FUNCTIONS ----------=====================

    function totalProducts(address storeAddress) public view returns (uint256) {
        return stores[storeAddress].storeProducts.length;
    }

    function createProduct(
        address storeAddress,
        string memory productName,
        uint256 price
    ) external onlyStoreOwner {
        Product memory product = Product(productName, price);

        stores[storeAddress].storeProducts.push(product);
    }

    function removeProduct(address storeAddress, string memory productName)
        external
        onlyStoreOwner
    {
        uint256 productIndex = getProductIndex(storeAddress, productName);
        Product[] storage products = stores[storeAddress].storeProducts;

        products[productIndex] = products[products.length - 1];
        products.pop();
    }

    //helper function for `removeProduct`
    function getProductIndex(address storeAddress, string memory productName)
        internal
        view
        returns (uint256)
    {
        for (uint256 i; i < stores[storeAddress].storeProducts.length; i++) {
            if (
                keccak256(
                    bytes(stores[storeAddress].storeProducts[i]._productName)
                ) == keccak256(bytes(productName))
            ) {
                return i;
            }
        }

        revert("Product not found in store");
    }

    function updateProduct(
        address storeAddress,
        uint256 productId,
        uint256 price
    ) external onlyStoreOwner {
        stores[storeAddress].storeProducts[productId]._price = price;
    }
}
