// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";


contract NFT1155Market is Initializable, ERC1155HolderUpgradeable, PausableUpgradeable, AccessControlUpgradeable, EIP712Upgradeable, UUPSUpgradeable {
    IERC1155Upgradeable public nft;
    IERC20Upgradeable public hiroToken;

    address public platformAddress;
    address public sellerBankAddress;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant PARAMETER_SETTER_ROLE = keccak256("PARAMETER_SETTER_ROLE");
    bytes32 public constant TRADE_HANDLER_ROLE = keccak256("TRADE_HANDLER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant SELLER_TYPEHASH = keccak256(
        "SELLER(address seller,address buyer,address token,uint256 tokenId,uint256 amount,uint256 price,uint256 deadline,uint256 nonce)"
    );

    uint256 private constant FEE_MAX_PERCENT = 1000000000; // 10**9
    uint256 public platformFeePercent;

    event SetPlatformFee(uint256 oldFeePercent, uint256 newFeePercent);

    mapping(address=>uint256) private _nonces;
    
    /* ECDSA signature. */
    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct HashData {
        address seller;
        address buyer;
        address token;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        uint256 deadline;
        uint256 nonce;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _name, 
        address _nftAddress,                
        address _hiroToken,
        address _sellerBankAddress,
        address _platformAddress,
        uint256 _feePercent
    ) external initializer {
        __ERC1155Holder_init();
        __Pausable_init();
        __AccessControl_init();
        __EIP712_init(_name,"1");
        __UUPSUpgradeable_init();

        nft = IERC1155Upgradeable(_nftAddress);
        hiroToken = IERC20Upgradeable(_hiroToken);

        sellerBankAddress = _sellerBankAddress;
        platformAddress = _platformAddress;
        platformFeePercent = _feePercent;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PARAMETER_SETTER_ROLE, msg.sender);
        _grantRole(TRADE_HANDLER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    // Calculate the fee for a given amount.
    function _calculateFeePercent(uint256 amount, uint256 _platformFeePercent)
        internal pure returns (uint256 fee, uint256 amountAfterFee)
    {
        fee = amount * _platformFeePercent / FEE_MAX_PERCENT;
        amountAfterFee = amount - fee;
    }

    // Set the platform fee percentage.
    function setFeePercent(uint256 newFeePercent)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newFeePercent < FEE_MAX_PERCENT/2, "Max fee reach");
        uint256 oldFeePercent = platformFeePercent;
        platformFeePercent = newFeePercent;

        emit SetPlatformFee(oldFeePercent, platformFeePercent);
    }

    function submitAirDrop(
		address buyer,
		address token,
		uint256 tokenId,
		uint256 amount,
		uint256 deadline,
		uint256 nonce,
        uint256 price,
        Sig calldata _sig
    )
        public
        whenNotPaused
    {
        // airdrop에 seller는 address(this)와 같아야 한다
        require( buyer != address(0), "Buyer address must not be zero");
        require( amount > 0, "Amount must be more than 0");
	require( block.timestamp < deadline, "Overdue order");
        require( IERC1155Upgradeable(token).balanceOf(address(this), tokenId) >= amount,"Seller insufficient NFT amount");
        if (price > 0) {
            require(hiroToken.balanceOf(msg.sender) >= price, "Please submit the asking price in order to complete the purchase");
        }
        

        bytes32 hash = buildSellerHash( HashData(address(this), buyer, token, tokenId, amount, price, deadline, nonce));
        (address recoveredAddress, ) = ECDSAUpgradeable.tryRecover(hash, _sig.v, _sig.r, _sig.s);
        require(hasRole(TRADE_HANDLER_ROLE, recoveredAddress),"not have role!");

        // Transfer nft to buyer
        IERC1155Upgradeable(token).safeTransferFrom(address(this), buyer, tokenId, amount, "0x0");
        if (price > 0) {
            (uint256 fee, uint256 amountAfterFee) = _calculateFeePercent(price, platformFeePercent);

            SafeERC20Upgradeable.safeTransferFrom(hiroToken,msg.sender, address(this), price);
            SafeERC20Upgradeable.safeTransfer(hiroToken, sellerBankAddress, amountAfterFee);
            SafeERC20Upgradeable.safeTransfer(hiroToken, platformAddress, fee);
        }
    }
    
    function permitAndSubmitAirDrop(        
        address buyer,
		address token,
		uint256 tokenId,
		uint256 amount,
		uint256 deadline,
		uint256 nonce,
        uint256 price,
        Sig calldata _sig,
        uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) 
    external  
    whenNotPaused
    {
        //IERC20PermitUpgradeable(address(underlying)).permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s);
        IERC20PermitUpgradeable(address(hiroToken)).permit(msg.sender, address(this), price, _deadline, _v, _r, _s);
        submitAirDrop(buyer, token, tokenId, amount, deadline, nonce, price, _sig);
    }

    // amount는 0이어서는 안된다. price는 0일수도 있다.
    function buildSellerHash(HashData memory params) public returns (bytes32){
        return _hashTypedDataV4(keccak256(abi.encode(
                SELLER_TYPEHASH,
                params.seller,
                params.buyer,
				params.token,
				params.tokenId,
                params.amount,
				params.price,
                params.deadline,
                _useNonce(params.buyer)
            )));
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }    

    function nonces(address owner) public view returns (uint256) {
        return _nonces[owner];
    }

    function _useNonce(address owner) internal virtual returns (uint256 current) {
        current = _nonces[owner];
        _nonces[owner] += 1;
    }


    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}


    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155ReceiverUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
