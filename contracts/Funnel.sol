//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

//TODO: implement tests in Hardhat.

contract Funnel {
    //TODO: think about Proxy Contracts-- why use them?
    //--- EVENTS ---
    event PaymentMade(address from, uint256 storeId, uint256 productId);

    //--- DATA_STRUCTURES / MEMBERS ---
    uint256 noOfStores;
    //TODO: have another mapping that keeps track of stores using an index.
    //TODO: consider making this `address payable => bool` so we can check if
    //      msg.sender is a store.
    mapping(uint256 => address payable) public storeAddresses;
    /* make a Store struct so we don't have to manage the state of a store by
        managing the indexes of three separate mappings-- seems error prone  */
    //TODO: add modifiers for functions.
    struct Product {
        uint256 _productId;
        uint256 _price;
    }

    struct Store {
        address payable _storeAddress;
        uint256 _storeTotalValue; //replacing mapping(uint256 => uint256) public storeVolume;
        //n.b. we hadn't come up with a use for this mapping yet.
        uint256 _noOfProducts; //replacing mapping(uint256 => uint256) public storeProductAmount;
        mapping(uint256 => Product) storeProducts; //mapping was `public` when no in struct.
    }

    struct Affiliate {
        address payable _affiliateAddress;
        uint256 _commision;
    }

    //--- FUNCTIONS ---
    function totalStores() public view returns (uint256) {
        return noOfStores;
    }

    function registerStore(address payable storeAddress)
        external
        returns (uint256)
    {
        uint256 storeIndex = totalStores();
        storeAddresses[storeIndex] = storeAddress;
        noOfStores += 1;

        return storeIndex;
    }

    //TODO: implement protocol for removing a store.

    function makePayment(
        uint256 storeId,
        // uint amount
        uint256 productId
    ) external payable returns (bool) {
        Product memory product = storeProducts[productId];
        uint256 price = product.price;
        require(msg.value == price, "Pay the right price");

        address payable storeAddress = storeAddresses[storeId];
        storeAddress.transfer(msg.value);
        storeVolume[storeId] += msg.value;

        emit PaymentMade(msg.sender, storeId, productId);

        return true;
    }

    //TODO: figure out why MultiSigWallet implemented Transaction Confirmation.

    //TODO: implement protocol for refunds
    //TODO: implement protocol for affiliate payments

    function totalProducts(uint256 storeId) public view returns (uint256) {
        return storeProductAmount[storeId];
    }

    //TODO: only stores should be able to create products.
    function createProduct(uint256 storeId, uint256 price)
        external
        returns (uint256)
    {
        uint256 productIndex = totalProducts(storeId);
        Product memory product = Product(productIndex, price);
        storeProductAmount[storeId] += 1;
        storeProducts[productIndex] = product;

        return productIndex;
    }
    //TODO: implement protocol for updating product price.
    //TODO: implement protocol for removing products
}
