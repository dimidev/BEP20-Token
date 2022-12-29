import { time, loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { expect } from 'chai';
import { ethers } from 'hardhat';

// format ether to wei
function formatEther(wei: number) {
  return ethers.utils.parseEther(wei.toString()).toString();
}

async function deployFixture() {
  const MyToken = await ethers.getContractFactory('MyToken');
  const [owner, addr1, addr2] = await ethers.getSigners();

  const myToken = await MyToken.deploy();

  await myToken.deployed();

  return { MyToken, myToken, owner, addr1, addr2 };
}

describe('MyToken', function () {
  describe('Deployment', function () {
    it('Should assign the total supply of tokens to the owner', async function () {
      const { myToken, owner } = await loadFixture(deployFixture);

      const ownerBalance = await myToken.balanceOf(owner.address);
      expect(await myToken.totalSupply()).to.equal(ownerBalance);
    });

    it('Should set the right owner', async function () {
      const { myToken, owner } = await loadFixture(deployFixture);

      expect(await myToken.owner()).to.equal(owner.address);
    });

    it('Should set the right tax receiver', async function () {
      const { myToken, owner } = await loadFixture(deployFixture);

      expect(await myToken.taxReceiver()).to.equal(owner.address);
    });
  });

  describe('Ownership', function () {
    it('Should not renounce ownership', async function () {
      const { myToken, owner } = await loadFixture(deployFixture);

      const tokenOwner = await myToken.owner();

      await myToken.renounceOwnership();

      expect(tokenOwner).to.equal(owner.address);
    });

    it('Should not transfer ownership', async function () {
      const { myToken, owner, addr1 } = await loadFixture(deployFixture);

      const tokenOwner = await myToken.owner();

      await myToken.transferOwnership(addr1.address);

      expect(tokenOwner).to.equal(owner.address);
    });
  });

  describe('Transfers', function () {
    it('Should transfer tokens between accounts', async function () {
      const { myToken, owner, addr1, addr2 } = await loadFixture(deployFixture);

      // Transfer 100 ether tokens from owner to addr1 without fee applied
      await expect(
        myToken.transfer(addr1.address, formatEther(100))
      ).to.changeTokenBalances(
        myToken,
        [owner, addr1],
        [formatEther(-100), formatEther(100)]
      );

      // Transfer 50 ether tokens from addr1 to the owner without fee applied
      await expect(
        myToken.connect(addr1).transfer(owner.address, formatEther(50))
      ).to.changeTokenBalances(
        myToken,
        [addr1, owner],
        [formatEther(-50), formatEther(50)]
      );

      // Transfer 50 ether tokens from addr1 to addr2 with fee applied
      const taxPercentage = await myToken.taxFee();
      const amount = ethers.BigNumber.from(formatEther(50));
      const taxAmount = amount.mul(taxPercentage).div(100);

      await expect(
        myToken.connect(addr1).transfer(addr2.address, amount)
      ).to.changeTokenBalances(
        myToken,
        [addr1, addr2, owner],
        [
          ethers.BigNumber.from(formatEther(-50)),
          amount.sub(taxAmount),
          taxAmount,
        ]
      );
    });

    it('Should emit Transfer events', async function () {
      const { myToken, owner, addr1, addr2 } = await loadFixture(deployFixture);

      // Transfer 100 tokens from owner to addr1 without fee applied
      await expect(myToken.transfer(addr1.address, formatEther(100)))
        .to.emit(myToken, 'Transfer')
        .withArgs(owner.address, addr1.address, formatEther(100));

      // Transfer 50 ether tokens from addr1 to the owner without fee applied
      await expect(
        myToken.connect(addr1).transfer(owner.address, formatEther(50))
      )
        .to.emit(myToken, 'Transfer')
        .withArgs(addr1.address, owner.address, formatEther(50));

      // Transfer 50 ether tokens from addr1 to addr2 with fee applied
      const taxPercentage = await myToken.taxFee();
      const amount = ethers.BigNumber.from(50);
      const taxAmount = amount.mul(taxPercentage).div(100);

      await expect(myToken.connect(addr1).transfer(addr2.address, taxAmount))
        .to.emit(myToken, 'Transfer')
        .withArgs(addr1.address, addr2.address, taxAmount);
    });

    it("Should fail if sender doesn't have enough balance", async function () {
      const { myToken, addr1, addr2 } = await loadFixture(deployFixture);

      const initialOwnerBalance = await myToken.balanceOf(addr2.address);

      // Try to send 100 ether tokens from addr1 (0 tokens) to addr2.
      await expect(
        myToken.connect(addr1).transfer(addr2.address, formatEther(100))
      ).to.be.revertedWith('ERC20: transfer amount exceeds balance');

      // addr2 balance shouldn't have changed.
      expect(await myToken.balanceOf(addr2.address)).to.equal(
        initialOwnerBalance
      );
    });

    it('Should fail if sender is not owner & amount is over maxTxAmount', async function () {
      const { myToken, addr1, addr2 } = await loadFixture(deployFixture);

      // transfer 100k ether to addr1
      myToken.transfer(addr1.address, formatEther(100_000));

      const initialOwnerBalance = await myToken.balanceOf(addr2.address);

      // Try to send 100k ether tokens from addr1 (0 tokens) to addr2.
      await expect(
        myToken.connect(addr1).transfer(addr2.address, formatEther(100_000))
      ).to.be.revertedWith('Transfer amount exceeds the maxTxAmount');

      // addr2 balance shouldn't have changed.
      expect(await myToken.balanceOf(addr2.address)).to.equal(
        initialOwnerBalance
      );
    });

    it('Should fail if sender is not owner & new balance is over maxWallet', async function () {
      const { myToken, addr1, addr2 } = await loadFixture(deployFixture);

      // transfer 100k ether to addr1
      myToken.transfer(addr1.address, formatEther(100_000));

      // Try to send 10k ether tokens from addr1 (0 tokens) to addr2.
      const taxPercentage = await myToken.taxFee();
      const amount = ethers.BigNumber.from(ethers.utils.parseEther('10000'));
      const taxAmount = amount.mul(taxPercentage).div(100);

      await expect(
        myToken.connect(addr1).transfer(addr2.address, amount)
      ).to.changeTokenBalances(
        myToken,
        [addr1, addr2],
        [ethers.utils.parseEther('-10000'), amount.sub(taxAmount)]
      );

      const initialOwnerBalance = await myToken.balanceOf(addr2.address);

      await expect(
        myToken.connect(addr1).transfer(addr2.address, formatEther(15_000))
      ).to.be.revertedWith('Max wallet exceeded');

      // addr2 balance shouldn't have changed.
      expect(await myToken.balanceOf(addr2.address)).to.equal(
        initialOwnerBalance
      );
    });
  });
});
