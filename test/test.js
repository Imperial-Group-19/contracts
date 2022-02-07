const { expect } = require("chai");
const { ethers } = require("hardhat");

// Tests here https://hardhat.org/guides/waffle-testing.html

describe("Funnel", function () {
    it("Store CRUD", async function () {

        const [owner] = await ethers.getSigners();

        const Funnel = await ethers.getContractFactory("Funnel");
        const funnel = await Funnel.deploy();
        await funnel.deployed();

        // create store
        const registerStoreTx = await funnel.registerStore("0xaae47EaE4DDd4877e0Ae0Bc780cFAEE3cc3B52cB");

        await registerStoreTx.wait();

        expect(await funnel.totalStores()).to.equal(1);

        let store = await funnel.getStore("0xaae47EaE4DDd4877e0Ae0Bc780cFAEE3cc3B52cB");

        expect(store._storeOwner).to.equal(owner.address);
        expect(store._storeAddress).to.equal("0xaae47EaE4DDd4877e0Ae0Bc780cFAEE3cc3B52cB");

        // update store

        const updateStoreTx = await funnel.updateStoreAddress("0xaae47EaE4DDd4877e0Ae0Bc780cFAEE3cc3B52cB", "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4");

        await updateStoreTx.wait();

        let storeNew = await funnel.getStore("0x5B38Da6a701c568545dCfcB03FcB875f56beddC4");
        let storeOld = await funnel.getStore("0xaae47EaE4DDd4877e0Ae0Bc780cFAEE3cc3B52cB");

        expect(storeNew._storeOwner).to.equal(owner.address);
        expect(storeNew._storeAddress).to.equal("0x5B38Da6a701c568545dCfcB03FcB875f56beddC4");
        expect(storeOld._storeAddress).to.equal("0x0000000000000000000000000000000000000000");


    });
});
  