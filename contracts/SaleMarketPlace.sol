// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract SaleMarketPlace is Initializable, OwnableUpgradeable, ERC721HolderUpgradeable, UUPSUpgradeable {
    IERC721Upgradeable public nftCollection;
    IERC20Upgradeable public hiroToken;
    address public platformAddress;
    address public sellerBankAddress;

    uint256 private constant FEE_MAX_PERCENT = 1000000000; // 10**9
    uint256 public platformFeePercent;

    mapping(uint256 => MarketItem) public items;

    string public marketName;

    struct MarketItem {
        uint256 itemNo;
        //  address nftContract;
        uint256 tokenId;
        uint256 amount;
        uint256 remain;   
        //  address payable seller;
        address seller;
        uint256 price;
        uint256 fee;
        bool isUser;
        bool paused;
    }

    /* ECDSA signature. */
    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    event MarketItemCreated (
        uint256 indexed itemNo,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 amount,
        address seller,
        uint256 price,
        bool paused
    );

    event MarketItemSold(
        uint256 indexed itemNo,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price
    );

    event SetPlatformFee(uint256 oldFeePercent, uint256 newFeePercent);

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
    ) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();

        nftCollection = IERC721Upgradeable(_nftAddress);
        hiroToken = IERC20Upgradeable(_hiroToken);

	marketName = _name;

        sellerBankAddress = _sellerBankAddress;
        platformAddress = _platformAddress;
        platformFeePercent = _feePercent;
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
        onlyOwner
    {
        require(newFeePercent < FEE_MAX_PERCENT/2, "Max fee reach");
        uint256 oldFeePercent = platformFeePercent;
        platformFeePercent = newFeePercent;

        emit SetPlatformFee(oldFeePercent, platformFeePercent);
    }

    // Add items for sale, and set prices.
    // Used only when registering for the first time on the platform.
    // The mint of the NFT item must be in this contract.
    function registerSaleItem(uint256 tokenId, uint256 amount, uint256 price, uint256 itemNo, uint256 fee)         
        external 
        onlyOwner  
    {
        require(fee < FEE_MAX_PERCENT/2, "Must not be greater than FEE_MAX");
        require(price > 0, "Price must be greater than 0");
        require(items[itemNo].itemNo == 0, "ItemNo already exists");
        for (uint256 i = tokenId; i < tokenId + amount; i++) {
            require(nftCollection.ownerOf(i) == address(this), "Item is not owned by the contract");
        }

        items[itemNo] = MarketItem(itemNo, tokenId, amount, amount, address(this), price, fee, false, false);

        emit MarketItemCreated(
            itemNo,
            address(nftCollection),
            tokenId,
            amount,
            address(this),
            price,
            false
        );
    }

    // Set a price to sell NFT items (for users)
    function makeSaleItem(uint256 tokenId, uint256 price, uint256 itemNo) external {
        require(price > 0, "Price must be greater than 0");
        require(items[itemNo].itemNo == 0, "ItemNo already exists");
        require(nftCollection.ownerOf(tokenId) == msg.sender, "The function caller does not own the token");
        require(nftCollection.getApproved(tokenId) == address(this), "The token is not approved by this contract");

        items[itemNo] = MarketItem(itemNo, tokenId, 1, 1, msg.sender, price, platformFeePercent, true, false);

        // nftCollection.transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            itemNo,
            address(nftCollection),
            tokenId,
            1,
            address(this),
            price,
            false
        );
    }

    function pausedSaleItem(uint256 itemNo) external {
        require(items[itemNo].itemNo != 0, "ItemNo does not exist");
        if (owner() != msg.sender) {
            require(items[itemNo].seller == msg.sender, "Not the owner of the item");
            require(items[itemNo].isUser == true, "The item is not registered by the user");
        }

        items[itemNo].paused = true;        
    }

    function unpausedSaleItem(uint256 itemNo) external onlyOwner {
        require(items[itemNo].itemNo != 0, "ItemNo does not exist");
        if (owner() != msg.sender) {
            require(items[itemNo].seller == msg.sender, "Not the owner of the item");
            require(items[itemNo].isUser == true, "The item is not registered by the user");
        }

        items[itemNo].paused = false;        
    }

    function changeSaleItemPrice(uint256 itemNo, uint256 price) external {
        require(items[itemNo].itemNo != 0, "ItemNo does not exist");
        require(price > 0, "Price must be greater than 0");
        if (owner() != msg.sender) {
            require(items[itemNo].seller == msg.sender, "Not the owner of the item");
            require(items[itemNo].isUser == true, "The item is not registered by the user");
        }

        items[itemNo].price = price;        
    }

    function buyMarketSaleItem(
        uint256 tokenId,
        uint256 itemNo,
        uint256 price
    ) 
    public 
    {
        require(items[itemNo].itemNo != 0, "ItemNo does not exist");
        MarketItem memory marketItem = items[itemNo];
        address seller = marketItem.seller;
        uint256 itemPrice = marketItem.price;
        uint256 platformFee = marketItem.fee;
        bool paused = marketItem.paused;
        bool isUser = marketItem.isUser;
        if (isUser == true) {
            platformFee = platformFeePercent;
        }
        require(hiroToken.balanceOf(msg.sender) >= itemPrice, "Please submit the asking price in order to complete the purchase");
        require(itemPrice == price, "Different prices");
        //require(msg.value == itemPrice, "Please submit the asking price in order to complete the purchase");
        require(marketItem.tokenId <= tokenId, "tokenId is small");
        require(marketItem.tokenId + marketItem.amount > tokenId, "tokenId is large");
        require(nftCollection.ownerOf(tokenId) == seller, "The contract does not have the tokenId of the nft");
        // require(marketItem.sold != true, "This Sale has alredy finnished");
        require(paused == false, "This product is paused");
        require(marketItem.remain > 0, "The product is out of stock");
        items[itemNo].remain--;


        (uint256 fee, uint256 amountAfterFee) = _calculateFeePercent(price, platformFee);

        SafeERC20Upgradeable.safeTransferFrom(hiroToken,msg.sender, address(this), price);
        if (isUser == true) {
            SafeERC20Upgradeable.safeTransfer(hiroToken, seller, amountAfterFee);
        } else {
            SafeERC20Upgradeable.safeTransfer(hiroToken, sellerBankAddress, amountAfterFee);
        }
        SafeERC20Upgradeable.safeTransfer(hiroToken, platformAddress, fee);

        nftCollection.transferFrom(seller, msg.sender, tokenId);
        
        emit MarketItemSold(
            itemNo,
            tokenId,
            seller,
            msg.sender,
            price
        );
    }

    function permitAndBuyMarketSaleItem(        
        uint256 tokenId,
        uint256 itemNo,
        uint256 _amount, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) 
    external  
    {
        //IERC20PermitUpgradeable(address(underlying)).permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s);
        IERC20PermitUpgradeable(address(hiroToken)).permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s);
        buyMarketSaleItem(tokenId, itemNo, _amount);
    }

    function changeMarketItemPrice(uint256 itemNo, uint256 price) external onlyOwner  {
        require(items[itemNo].itemNo != 0, "The product does not exist");
        items[itemNo].price = price;
    }

    function checkFirstOwnedToken(uint256 startTokenId,uint256 range) public view returns (uint256) {
        for (uint tokenId = startTokenId; tokenId < startTokenId + range; tokenId++) {
            try nftCollection.ownerOf(tokenId) returns (address owner) {
                if (owner != address(0)) {
                    return tokenId;
                }
            } catch {
                continue;
            }
        }

        return 0;
    }

       
    function fetchMarketItem(uint256 itemNo) external view returns (MarketItem memory) {
        require(items[itemNo].itemNo != 0, "The product does not exist");

        return items[itemNo];
    }

    
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function onERC721Received(address,address,uint256,bytes memory) 
        public 
        override 
        pure    
        returns (bytes4) 
    {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
