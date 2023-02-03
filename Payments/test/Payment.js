const { ethers } = require("hardhat");
const { expect } = require("chai");

const parse = ethers.utils.parseEther;

describe("Payment", function () {

    var paymentContract;
    var [owner, addr1, addr2] = [];
    var usdt;

    const price1 = parse("1");
    const price2 = parse("2");
    const newprice1 = parse("10");
    const newprice2 = parse("20");

    it("deploy usdt", async function () {
        const mockUSDTf =  await ethers.getContractFactory("MockToken");
        [owner, addr1, addr2] = await ethers.getSigners();
        usdt = await mockUSDTf.deploy();

        await usdt.deployed();
    });

    it("deploy payments", async function () {

        const paymentF = await ethers.getContractFactory("KYCPayments");

        paymentContract = await paymentF.deploy(usdt.address, price1, price2);
        await paymentContract.deployed();

        const _owner = await paymentContract.owner();
        expect(_owner).to.be.equal(owner.address);
    });

    describe("Price change", function () {
        it("Should change price by owner", async function () {
            const tx = await paymentContract.changePrice(0, newprice1);
            await tx.wait();
            const price = await paymentContract.prices(0);
            expect(price).to.be.equal(newprice1);
        });
        it("Should not change price to 0", async function () {
            expect(
                paymentContract.changePrice(1, parse("0"))
                ).to.be.revertedWith("New price can't be zero!");
        });
        it("Should not change price by non-owner", async function () {
            expect(
                paymentContract.connect(addr1).changePrice(0, price1)
            ).to.be.reverted;
        });
        it("Should not change price out of bounds", async function () {
            expect(
                paymentContract.changePrice(2, price1)
            ).to.be.reverted;
        });
    });

    describe("Read balance", function () {
        it("Should read balance by owner", async function () {
            const balance = await paymentContract.readBalance();
            expect(balance).to.be.equal(parse("0"));
        });
        it("Should not read balance by non-owner", async function () {
            expect(
                paymentContract.connect(addr1).readBalance()
            ).to.be.reverted;
        });
    });

    describe("Bill management", function () {
        it("Should create bill", async function () {
            expect(
                await paymentContract.createBill(addr1.address, parse("50"), "bill1")
            ).to.satisfy;
        });

        it("Should not create bill with occupied id", async function () {
            expect(
                paymentContract.createBill(addr1.address, parse("50"), "bill1")
            ).to.be.revertedWith("Bill id is not available!");
        });

        it("Should read billed amount by owner", async function () {
            expect(
                await paymentContract.readBilledAmount(addr1.address, "bill1")
            ).to.be.equal(parse("50"));
        });

        it("Should change billed amount", async function () {
            expect(
                await paymentContract.changeBilledAmount(addr1.address, "bill1", parse("15"))
            ).to.satisfy;

        });

        it("Should there be a minimum amount?");

        it("Should read billed amount by billed user", async function () {
            expect(
                await paymentContract.connect(addr1).readBilledAmount(addr1.address, "bill1")
            ).to.be.equal(parse("15"));
        });

        it("Access control tests", async function () {
            expect(
                paymentContract.connect(addr2).createBill(addr1.address, parse("228"), "bill228")
            ).to.be.reverted;

            expect(
                paymentContract.connect(addr2).readBilledAmount(addr1.address, "bill1")
            ).to.be.revertedWith("Not authorized!");

            expect(
                paymentContract.changeBilledAmount(addr1.address, "bill1", parse("322"))
            ).to.be.reverted;
        });

    });

    describe("Payments", function () {
        //bill1
        it("Should revert with invalid offer", async function () {
            expect(
                paymentContract.connect(addr1).generalPayments(2)
            ).to.be.revertedWith("Incorrect option!");
        });

        it("Should revert without allowance", async function () {
            expect(
                paymentContract.connect(addr1).generalPayments(0)
            ).to.be.revertedWith("Not enough allowance, approve your USDT first!");
        });

        it("Should revert without usdt", async function () {
            await usdt.connect(addr1).approve(paymentContract.address, newprice1);
            expect(
                paymentContract.connect(addr1).generalPayments(0)
            ).to.be.revertedWith("Not enough USDT!");
        });

        it("General payments", async function () {
            await usdt.mint(addr1.address, newprice1);
            expect(
                await usdt.balanceOf(addr1.address)
            ).to.be.equal(newprice1);
            //now all requirements are satisfied
            expect(
                await paymentContract.connect(addr1).generalPayments(0)
            ).to.emit("KYCPayments", "PaymentCompleted").withArgs(
                addr1.address, newprice1, 0, "none"
            );

            expect(
                await usdt.balanceOf(addr1.address)
            ).to.be.equal(parse("0"));
        });

        //bill2
        it("Should revert with 0 bill amount", async function () {
            await paymentContract.createBill(addr2.address, parse("0"), "bill1");
            expect(
                paymentContract.connect(addr2).customPayments("bill1")
            ).to.be.revertedWith("Invalid bill!");
        });

        it("Should revert without allowance", async function () {
            await paymentContract.createBill(addr2.address, newprice2, "bill2");
            expect(
                paymentContract.connect(addr2).customPayments("bill2")
            ).to.be.revertedWith("Not enough allowance, approve your USDT first!");
        });

        it("Should revert without usdt", async function () {
            await usdt.connect(addr2).approve(paymentContract.address, newprice2);
            expect(
                paymentContract.connect(addr2).customPayments("bill2")
            ).to.be.revertedWith("Not enough USDT!");
        });

        it("Custom payments", async function () {
            await usdt.mint(addr2.address, newprice2);
            expect(
                await usdt.balanceOf(addr2.address)
            ).to.be.equal(newprice2);

            expect(
                await paymentContract.connect(addr2).customPayments("bill2")
            ).to.emit("KYCPayments", "PaymentCompleted").withArgs(
                addr2.address, newprice2, 2, "bill2"
            );
            expect(
                await usdt.balanceOf(addr2.address)
            ).to.be.equal(parse("0"));
        });
    });
    describe("Withdraw", function () {
        it("Contract balance should be sum of both prices", async function () {
            expect(
                await paymentContract.readBalance()
            ).to.be.equal(newprice1.add(newprice2));
        });
        it("Should not withdraw if not an owner", async function () {
            expect(
                paymentContract.connect(addr1).withdrawBalance(addr1.address)
            ).to.be.reverted;
        });

        it("Should withdraw to non-zero address", async function () {
            expect(
                paymentContract.withdrawBalance(ethers.constants.AddressZero)
            ).to.be.revertedWith("Address can't be zero!");

            expect(
                await usdt.balanceOf(owner.address)
            ).to.be.equal(parse("0"));

            expect(
                await paymentContract.withdrawBalance(owner.address)
            ).to.satisfy;

            expect(
                await usdt.balanceOf(owner.address)
            ).to.be.equal(newprice1.add(newprice2));
        });
    });
});
