//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

//TODO: implement tests in Hardhat.

contract Funnel {
    //TODO: think about Proxy Contracts-- why use them?
    //--- EVENTS ---
    event PaymentMade(address from, address storeAddress, uint256 productId);

    //--- DATA_STRUCTURES / MEMBERS ---
    struct Product {
        uint256 _productId;
        uint256 _price;
    }

    struct Store {
        address payable _storeAddress;
        uint256 _storeTotalValue;
        uint256 _noOfProducts;
        mapping(uint256 => Product) storeProducts;
    }

    struct Affiliate {
        address payable _affiliateAddress;
        uint256 _commision;
    }

    uint256 noOfStores;
    //TODO: what do you think of the second mapping?
    mapping(address => Store) public stores;
    mapping(address => bool) isOwner;

    /* make a Store struct so we don't have to manage the state of a store by
        managing the indexes of three separate mappings-- seems error prone  */
    //TODO: add modifiers for functions.

    modifier onlyStoreOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    //--- FUNCTIONS ---
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
        store._noOfProducts = 0;

        uint256 storeIndex = totalStores();
        noOfStores++;

        return storeIndex;
    }

    //TODO: implement protocol for removing a store.

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

    // //TODO: implement protocol for refunds
    // //TODO: implement protocol for affiliate payments

    function totalProducts(address storeAddress) public view returns (uint256) {
        return stores[storeAddress]._noOfProducts;
    }

    //TODO: only store owners should be able to create products.
    function createProduct(address storeAddress, uint256 price)
        external
        onlyStoreOwner
        returns (uint256)
    {
        uint256 productIndex = stores[storeAddress]._noOfProducts;
        Product memory product = Product(productIndex, price);

        stores[storeAddress].storeProducts[productIndex] = product;
        stores[storeAddress]._noOfProducts++;

        return productIndex;
    }

    //TODO: implement protocol for updating product price.
    //TODO: implement protocol for removing products
    function removeProduct(address storeAddress, uint256 productIndex)
        external
        onlyStoreOwner
    {
        delete stores[storeAddress].storeProducts[productIndex];
    }
    
    function updateProduct(address storeAddress, uint256 productId, uint256 price) 
        external
    {
        stores[storeAddress].storeProducts[productId]._price = price;
    }

    function updateStoreAddress(address storeAddress, address payable newStoreAddress) 
        external
    {   
        Store storage store = stores[newStoreAddress];
        store._storeAddress = newStoreAddress;
        store._storeTotalValue = stores[storeAddress]._storeTotalValue;
        store._noOfProducts = stores[storeAddress]._noOfProducts;

        for(uint256 i; i<stores[storeAddress]._noOfProducts;  i++){
            store.storeProducts[i] = stores[storeAddress].storeProducts[i]; 
        }
        
        delete stores[storeAddress];

    }


}
