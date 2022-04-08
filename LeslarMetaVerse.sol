// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9 <0.9.0;

import 'erc721a/contracts/ERC721A.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
contract LeslarMetaVerse is ERC721A, ReentrancyGuardUpgradeable, AccessControlUpgradeable {

  using StringsUpgradeable for uint256;
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  //list user
  bytes32 public merkleRoot;
  //flaging kind of sale
  mapping(address => bool) public presalelistClaimed;

  string public uriPrefix;
  string public uriSuffix;
  string public hiddenMetadataUri;
  
  uint256 public cost;
  uint256 public maxSupply;
  uint256 public maxMintAmountPerTx;

  bool public paused;
  bool public preSaleMintEnabled;
  bool public revealed;

  function initialize(string memory _tokenName,
    string memory _tokenSymbol,
    uint256 _cost,
    uint256 _maxSupply,
    uint256 _maxMintAmountPerTx,
    string memory _hiddenMetadataUri) external initializer   {
    _ERC721A_init(_tokenName, _tokenSymbol);
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(PAUSER_ROLE, msg.sender);
    setCost(_cost);
    maxSupply = _maxSupply;
    setMaxMintAmountPerTx(_maxMintAmountPerTx);
    setHiddenMetadataUri(_hiddenMetadataUri);
    uriPrefix = '';
    uriSuffix = '.json';
    paused = true;
    preSaleMintEnabled= false;
    revealed = false;
  }
  

  modifier mintCompliance(uint256 _mintAmount) {
    require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, 'Invalid mint amount!');
    require(totalSupply() + _mintAmount <= maxSupply, 'Max supply exceeded!');
    _;
  }

  modifier mintPriceCompliance(uint256 _mintAmount) {
    require(msg.value >= cost * _mintAmount, 'Insufficient funds!');
    _;
  }

  
  function preSaleMint(uint256 _mintAmount, bytes32[] calldata _merkleProof) public payable mintCompliance(_mintAmount) mintPriceCompliance(_mintAmount) {
    // Verify whitelist requirements
    require(preSaleMintEnabled, 'The whitelist sale is not enabled!');
    require(!presalelistClaimed[_msgSender()], 'Address already claimed!');
    bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
    require(MerkleProofUpgradeable.verify(_merkleProof, merkleRoot, leaf), 'The user is not logged in to the presale participant');
    
    presalelistClaimed[_msgSender()] = true;
    _safeMint(_msgSender(), _mintAmount);
  }

  function mint(uint256 _mintAmount) public payable mintCompliance(_mintAmount) mintPriceCompliance(_mintAmount) {
    require(!paused, 'The contract is paused!');

    _safeMint(_msgSender(), _mintAmount);
  }
  
  function mintForAddress(uint256 _mintAmount, address _receiver) public mintCompliance(_mintAmount)  {
    _safeMint(_receiver, _mintAmount);
  }

  function walletOfOwner(address _owner) public view returns (uint256[] memory) {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
    uint256 currentTokenId = _startTokenId();
    uint256 ownedTokenIndex = 0;
    address latestOwnerAddress;

    while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply) {
      TokenOwnership memory ownership = _ownerships[currentTokenId];

      if (!ownership.burned && ownership.addr != address(0)) {
        latestOwnerAddress = ownership.addr;
      }

      if (latestOwnerAddress == _owner) {
        ownedTokenIds[ownedTokenIndex] = currentTokenId;

        ownedTokenIndex++;
      }

      currentTokenId++;
    }

    return ownedTokenIds;
  }

  function _startTokenId() internal view virtual override returns (uint256) {
    return 1;
  }

  function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
    require(_exists(_tokenId), 'ERC721Metadata: URI query for nonexistent token');

    if (revealed == false) {
      return hiddenMetadataUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
        : '';
  }

  function setRevealed(bool _state) public  {
    revealed = _state;
  }

  function setCost(uint256 _cost) public onlyRole(DEFAULT_ADMIN_ROLE) {
    cost = _cost;
  }

  function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) public onlyRole(DEFAULT_ADMIN_ROLE) {
    maxMintAmountPerTx = _maxMintAmountPerTx;
  }

  function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyRole(DEFAULT_ADMIN_ROLE) {
    hiddenMetadataUri = _hiddenMetadataUri;
  }

  function setUriPrefix(string memory _uriPrefix) public onlyRole(DEFAULT_ADMIN_ROLE) {
    uriPrefix = _uriPrefix;
  }

  function setUriSuffix(string memory _uriSuffix) public onlyRole(DEFAULT_ADMIN_ROLE) {
    uriSuffix = _uriSuffix;
  }

  function setPaused(bool _state) public onlyRole(PAUSER_ROLE) {
    paused = _state;
  }

  
  function setMerkleRoot(bytes32 _merkleRoot) public onlyRole(DEFAULT_ADMIN_ROLE) {
    merkleRoot = _merkleRoot;
  }
  
  function setPreSaleMintEnabled(bool _state) public onlyRole(DEFAULT_ADMIN_ROLE) {
    preSaleMintEnabled = _state;
  }

  function withdraw() public onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
    // This will transfer the remaining contract balance to the owner.
    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not Admion Role");
    (bool os, ) = payable(msg.sender).call{value: address(this).balance}('');
    require(os);
    // =============================================================================
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return uriPrefix;
  }
}
