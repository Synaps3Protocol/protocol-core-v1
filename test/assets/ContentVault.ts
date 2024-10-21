import hre from 'hardhat'
import { expect } from 'chai'
import { switcher, getAccounts } from './helpers/CommonHelper'
import { ContentVault, Ownership, Referendum } from '@/typechain-types'
import {
  deployInitializedContentVault
} from './helpers/ContentVaultHelper'



describe('ContentVault', function () {

  const tests: { id: number, name: string, data: string }[] = [
    // example storing LIT in format: chain.ciphertext.dataToEncryptHash
    // This data is needed in decryption process and obtained during encryption.
    // https://developer.litprotocol.com/sdk/access-control/quick-start#encryption
    { id: 10, name: 'LIT', data: "ethereum.dGVzdF9zZWN1cmVMb25nQ29udGVudF93YXRjaGl0X3Byb3RvY29sX3ZhdWx0c3RvcmFnZQ==.4Kw2DRwEmqK25fOi4bnJ6KLgs8O5gpmxu25VfAUBXXQ=" },
    // RSA
    { id: 20, name: 'RSA', data: "8c7e50310a8fc4be1bbadfcd8e9359c8b304dbd96dbe1f5b8ee5b8a249b19fc8403e80aeb2a4b9ebec50fabe98b6e632858571aeb4bde8de2a6471d9a41b1b7c5082d2f2" },
    // chachapoly
    { id: 30, name: 'ChaChaPoly', data: "e4bfc4a68d3017c1c50cbb65.f579fc8e4f8e917127cd6d10a85ccbf2.976f64c6011a0a94b9495c1bcf5e7e4ecff4c4e1e9f5293d59b19670f7e945a8a3f1b5045fbe7255ec3d41b5" },
    // AES
    { id: 40, name: 'AES', data: "2b2e31fc7c0e47818e18d12b.724f1e73e41f6c5e8bc14a7c6f4d481d.3c4a42b0fcd3e4d5856f8e55b5e8f7e45ac8e58ed8bde3b7d1c58bd74eb3d407ab59b252de04a8c390bbd5" }
  ];

  let referendum: Referendum;
  let contentVault: ContentVault;
  let ownership: Ownership;

  let owner: hre.ethers.HardhatEthersSigner;
  let governor: hre.ethers.HardhatEthersSigner;

  before(async () => {
    [
      contentVault,
      ownership,
      referendum
    ] = await switcher(deployInitializedContentVault);

    [owner, governor] = await getAccounts()
    // we need set a governor fake account 
    await (await referendum.setGovernance(governor)).wait()
    // then as "governor account" set a verified role
    // to bypass register only approved content.. 
    await (await referendum.connect(governor).grantVerifiedRole(owner)).wait();
  })

  tests.forEach((test) => {

    it(`Should store and retrieve ${test.name} successfully.`, async function () {
      // first needed to register content and prove ownership to set secure data
      await (await ownership.registerContent(owner, test.id)).wait();
      const encoder = hre.ethers.AbiCoder.defaultAbiCoder()
      const cypherBytes = encoder.encode(["string"], [test.data])
      await contentVault.setContent(test.id, cypherBytes);

      const expected = await contentVault.getContent(test.id)
      const decoded = encoder.decode(["string"], expected)[0];
      expect(decoded).to.be.equal(test.data)
    })
  })

})
