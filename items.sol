// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./base64.sol";

enum ItemType {
    Payable, // 0 = default
    Claimable // 1
}

contract ERC1155Sale is ERC1155, Ownable {
    using Strings for uint256;
//Basic Smart Contract which holds onchain content IE:Code,Images,links etc onchain. 
//By Malcolm Dane & The New Management Inc
    constructor() ERC1155("on-chain-storage") {}

    struct DomElem {
        uint256 price;
        uint256 maxSupply;
        uint256 mintedSupply;
        ItemType itemType;
        string name;
        string imageUrl;
        string animationUrl;
    }

    mapping(uint256 => DomElem) public items;
    uint256 public totalItems;

    mapping (uint256 => bool) private _saleStarted;
    string public element;

    modifier whenSaleStarted(uint256 itemId) {
        require(_saleStarted[itemId], "Sale not started");
        _;
    }

    // ----- View functions -----

    function saleStarted(uint256 itemId) public view returns(bool) {
        return _saleStarted[itemId];
    }

    function uri(uint256 tokenId) public view override returns (string memory output) {
         address from = msg.sender;

        uint256 x=balanceOf(from,tokenId);
        DomElem memory item = items[tokenId];

        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{',
            '"name": "', item.name, '",',
            '"element": "', element, '",',
            '"animation_url": "', item.animationUrl, '",',
            '"image": "', item.imageUrl, '"',
            '}'
        ))));
        if(x>0){

        output = string(abi.encodePacked('data:application/json;base64,', json));}
        else{

            output='';
        }

    }

    function listItems() public view returns (DomElem[] memory _items) {
        _items = new DomElem[](totalItems);

        for (uint256 i = 0; i < totalItems; i++) {
            _items[i] = items[i];
        }
    }

    // ----- Internal functions -----

    // Buy item
    function _buyItem(uint256 itemId, uint256 amount)
        internal
        whenSaleStarted(itemId)
    {
        require(itemId < totalItems, "No itemId");

        DomElem storage item = items[itemId];

        require(item.mintedSupply + amount <= items[itemId].maxSupply, "Out of stock");

        // buy item
        item.mintedSupply += amount;
        _mint(msg.sender, itemId, amount, "");
    }

    // -------- User functions

    // Pays in ETH, requires not Claimable
    function buyItem(uint256 itemId, uint256 amount)
        external
        payable
        whenSaleStarted(itemId)
    {
        require(itemId < totalItems, "No itemId");

        DomElem memory item = items[itemId];

        require(item.itemType == ItemType.Payable, "Item is not payable, cant buy with ETH");
        require(item.price * amount <= msg.value, "Not enough ETH");

        _buyItem(itemId, amount);
    }

    // ----- Admin functions -----

    function setDescription(string memory _element) public onlyOwner {
        element = _element;
    }

    // reserveItem onlyOwner, allows admin to claim any amount of any token,
    function reserveItem(uint256 itemId, uint256 amount) public onlyOwner {
        // require(_saleStarted[itemId] == false, "Only claim when sale is not active");

        require(itemId < totalItems, "No itemId");

        DomElem storage item = items[itemId];

        require(item.mintedSupply + amount <= item.maxSupply, "Not enough supply");

        item.mintedSupply += amount;
        _mint(msg.sender, itemId, amount, "");
    }

    function flipSaleStarted(uint256 itemId) external onlyOwner {
        _saleStarted[itemId] = !_saleStarted[itemId];
    }

    function startSaleAll() external onlyOwner {
        for (uint256 itemId = 0; itemId < totalItems; itemId++) {
            _saleStarted[itemId] = true;
        }
    }

    function stopSaleAll() external onlyOwner {
        for (uint256 itemId = 0; itemId < totalItems; itemId++) {
            _saleStarted[itemId] = false;
        }
    }

    // Add new item to the marketplace
    function _addItem(string memory name, string memory imageUrl, string calldata animationUrl, uint256 price, uint256 maxSupply, ItemType itemType, bool startSale) internal virtual {
        require(maxSupply > 0, "Invalid maxSupply");

        uint256 newItemId = totalItems;

        // create new item
        DomElem memory item = DomElem(price, maxSupply, 0, itemType, name, imageUrl, animationUrl);

        // add item to the array
        items[newItemId] = item;
        totalItems++;

        // should start sale right after adding?
        _saleStarted[newItemId] = startSale;

        emit ItemAdded(newItemId, name, imageUrl, price, maxSupply, itemType, startSale);
    }

    function addItem(string memory name, string memory imageUrl, string calldata animationUrl, uint256 price, uint256 maxSupply, ItemType itemType, bool startSale) public virtual onlyOwner {
        _addItem(name, imageUrl, animationUrl, price, maxSupply, itemType, startSale);
    }

    // Change price for item
    function changePrice(uint256 itemId, uint256 newPrice) public onlyOwner {
        require(itemId < totalItems, "No itemId");

        items[itemId].price = newPrice;
    }

    function changeItemType(uint256 itemId, uint256 itemType, uint256 newPrice) public onlyOwner {
        require(itemId < totalItems, "No itemId");
        require(ItemType(itemType) == ItemType.Payable || ItemType(itemType) == ItemType.Claimable, "Invalid itemType");

        items[itemId].itemType = ItemType(itemType);
        items[itemId].price = newPrice;
    }
    function myFunc() external payable {
    require(msg.value == 1000000000000000000, 'Need to send 1 ETH');
}

    // Withdraw sale money
    function withdraw() public virtual onlyOwner {
        uint256 _balance = address(this).balance;

        uint256 baseAmount = _balance;

        require(payable(msg.sender).send(baseAmount));
    }

    event ItemAdded(uint256 itemId, string name, string imageUrl, uint256 price, uint256 maxSupply, ItemType itemType, bool startSale);

}
