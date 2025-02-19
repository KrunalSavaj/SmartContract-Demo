// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MarketPlace {

  error AlreadyListed(address _NftAddress, uint256 _id, address _owner);

  event _setListNFT(address indexed _NftAddress, uint256 _id, address indexed _owner, uint256 price);
  event _BuyNft(address indexed _NftAddress, uint256 _id, address indexed _seller, address indexed _Buyer, uint256 price);
  event _refundNft(address indexed _NftAddress, uint256 _id, address indexed _seller);

   // This struct for NFTDetail
    struct NFT {
        address Nft;
        uint256 NftId;
        address payMent;
        uint256 price;
    }

   // This struct for normal NFT sell detail
    struct ListNft {
     address payable seller;
     NFT nft;
     uint256 listedNumber;
     uint startAt;
     uint EndAt;
     bool isListed;
    }

  // This struct for Dutch auction NFT detail
    struct DutchList {
        address payable seller;
        NFT nft;
        uint256 listedNumber;
        uint startAt;
        uint EndAt;
        bool isListed;
        uint256 discountRate;
    }

  // MarketPlace owner Address
   address payable immutable public  owner;

  //  Marketplace name
  string public name = "Sahajanand MarketPlace";

  // NFT listing number generator
  uint256 ListOn;

  // This mapping for find NFT listing struct Number
   mapping(address => mapping(uint256 => uint)) public ListNumber;
  // This mapping is take below nuber and send Listing Nft
   mapping(uint256 => ListNft) public listNft;
  // This mapping is take below nuber and send dutchList Nft
   mapping(uint256 => DutchList) public dutchList;

 // msg.sender is owner of this MarketPlace
  constructor(){
    owner = payable (msg.sender);
  }


 //  This function is listing NFT on marketplace for particular time
  function setListNFT(
    address _Nft,
    uint256 _id,
    uint _price,
    address _payment,
    uint256 _startAt,
    uint256 _endAt)
    public
    returns(bool) {
      
      // NFT Contract
      IERC721 Item = IERC721(_Nft);
        
      // for time validation
      require(_startAt >= block.timestamp && _endAt >= _startAt, "Please provide correct time.");

      // Find index of NFT
      uint256 _ListNumber = ListNumber[_Nft][_id];
      // check NFT is listed or not.
      require(!listNft[_ListNumber].isListed , "Already listed NFT.");

      DutchList memory dutchItem = dutchList[_ListNumber];

      // if NFT is already list on dutch Auction so, first step is remove that NFT on other Auction and after list  
      if( dutchItem.isListed ) {
        // check caller is seller of NFT.
        require(dutchItem.seller == msg.sender, "This function call only seller of this NFT");
            
            // Remove NFT data from auction
            dutchList[_ListNumber] = DutchList({
                        seller : payable(address(0)),
                        nft    : NFT({
                                  Nft    : _Nft,
                                  NftId  : _id,
                                  payMent: address(0),
                                  price  : 0
                                }),
                        startAt : 0,
                        EndAt   : 0,
                        listedNumber  : 0,
                        isListed: false,
                        discountRate : 0
            });

          ListNumber[_Nft][_id] = 0;
      } else {
         ListOn += 1;
        _ListNumber = ListOn;
      }
       
       // trasfer ownership
      if(Item.ownerOf(_id) != address(this)) {
        Item.transferFrom(msg.sender, address(this), _id);
      }
      
      bool _isListed;
      address _seller;

      //  if price is 0 so, transaction fail and NFT is not listed
      if(_price == 0) {
        Item.transferFrom(address(this), msg.sender, _id);  
      } else {
        _seller = msg.sender;
        _isListed = true;
      }

        //  Update NFT on Listing data 
        listNft[_ListNumber] = ListNft({
            seller: payable(_seller),
            nft   : NFT({
                      Nft    : _Nft,
                      NftId  : _id,
                      payMent: _payment,
                      price  : _price
                  }),
            startAt: _startAt,
            EndAt  : _endAt,
            listedNumber : _ListNumber,
            isListed: _isListed
        });
     
        // if NFT is on list so, update ListNumber otherwise 0.
        if(_isListed){
          ListNumber[_Nft][_id] = _ListNumber;
          emit _setListNFT(_Nft, _id, msg.sender, _price);
        } else {
          ListNumber[_Nft][_id] = 0;
        }

        return true;
  }

  // This function is sell NFT to Buyer 
  function BuyNft(address _Nft, uint256 _id) external payable {
      
       // Find index of NFT
      uint256 _ListNumber = ListNumber[_Nft][_id];
      ListNft memory listItem = listNft[_ListNumber];

      // check NFT is listed or not.
      require(listItem.isListed == true, "This NFT is not on list.");
      
      // check NFT is on the sell ?
      require(block.timestamp >= listItem.startAt && block.timestamp < listItem.EndAt , "currently this NFT is not on sell.");
      
      // ERC20 payment address
      address _payment = listItem.nft.payMent;
      // price of NFT
      uint256 _price = listItem.nft.price;
      // seller address
      address _seller = listItem.seller;

      // payment methods if payment on ERC20  else if payment on ether
      if(_payment != address(0)) {
        uint256 _allownce = IERC20(_payment).allowance(msg.sender , address(this));

          if(_allownce >= _price) {
            IERC20(_payment).transferFrom(msg.sender , _seller, _price);
          } else {
            revert("Please approve your Token to address this.");
          }
          
      }
      else if (msg.value >= _price) {
        payable(_seller).transfer(_price);
      }
      else {
        revert("your payment is not enough to buy this NFT.");
      }
      
      // Transfer ownership of NFT to Buyer
      IERC721(_Nft).transferFrom(address(this), msg.sender, _id);
 
      // Remove from List data
      listNft[_ListNumber] = ListNft({
            seller: payable(address(0)),
            nft   : NFT({
                      Nft    : _Nft,
                      NftId  : _id,
                      payMent: address(0),
                      price  : 0
                  }),
            startAt: 0,
            EndAt  : 0,
            listedNumber : 0,
            isListed: false
        });
        
        // index set to 0 
        ListNumber[_Nft][_id] = 0;

        emit _BuyNft(_Nft, _id, _seller, msg.sender, _price);
  }

  // This function is listing NFT on Auction for particular time 
  function setListOnDutch(
    address _Nft,
    uint256 _id,
    uint _price,
    address _payment,
    uint256 _discountRate,
    uint256 _startAt,
    uint256 _endAt)
    public
     returns(bool) {
   
    // for time validation
    require(_startAt >= block.timestamp && _endAt >= _startAt, "Please provide correct time.");
    // Time validation
    require(_price > _discountRate * (_endAt - _startAt), "Price is not enough.");
  
    // Find index of NFT
      uint256 _ListNumber = ListNumber[_Nft][_id];
      ListNft memory listItem = listNft[_ListNumber];
      DutchList memory dutchItem = dutchList[_ListNumber];
      
      // check dutchItem is Already list or not
      require(!dutchItem.isListed, "Already Listed NFT.");

      // if NFT is already list on marketplace so, first step is remove that NFT on the marketplace and after list on Auction
      if(_ListNumber != 0) {
        // check caller is seller of NFT.
       require(listItem.seller == msg.sender, "This function call only seller of this NFT.");
                    
                    // Remove NFT data from other listing
                    listNft[_ListNumber] = ListNft({
                        seller : payable(address(0)),
                        nft    : NFT({
                                  Nft    : _Nft,
                                  NftId  : _id,
                                  payMent: address(0),
                                  price  : 0
                                }),
                        startAt : 0,
                        EndAt   : 0,
                  listedNumber  : 0,
                        isListed: false
                    });

          ListNumber[_Nft][_id] = 0;

      // else new listing take new ListNumber
      } else {
        ListOn += 1;
        _ListNumber = ListOn;
      }
      
      // NFT contract
      IERC721 Item = IERC721(_Nft);
      
      // Transfer ownership to address this
      if(Item.ownerOf(_id) != address(this)) {
        Item.transferFrom(msg.sender, address(this), _id);
      }
     
      // Update data on Auction
      dutchList[_ListNumber] = DutchList({
            seller : payable(msg.sender),
            nft    : NFT({
                      Nft    : _Nft,
                      NftId  : _id,
                      payMent: _payment,
                      price  : _price
                     }),
            startAt : _startAt,
            EndAt   : _endAt,
      listedNumber  : _ListNumber,
            isListed: true,
       discountRate : _discountRate
      });
      
      // set index of NFT
      ListNumber[_Nft][_id] = _ListNumber;

      return true;
  }

  // This function is sell Auction NFT to Buyer
  function BuyDutchNft(address _Nft, uint256 _id) external payable {
      
      // Find index of NFT
      uint256 _ListNumber = ListNumber[_Nft][_id];

      DutchList memory dutchItem = dutchList[_ListNumber];
      // check NFT is Listed
      require(dutchItem.isListed,"This NFT is not on list.");
      // check NFT is on the sell ? 
      require(block.timestamp >= dutchItem.startAt && block.timestamp < dutchItem.EndAt , "currently this NFT is not on sell.");
       
      // ERC20 payment address
      address _payment = dutchItem.nft.payMent;
      // price of NFT
      uint256 _price = DutchPrice(_Nft,_id);
      // seller address
      address _seller = payable(dutchItem.seller);
  
      // payment methods if payment on ERC20  else if payment on ether
      if(_payment != address(0)) {
        uint256 _allownce = IERC20(_payment).allowance(msg.sender , address(this));
          if(_allownce >= _price) {
            IERC20(_payment).transferFrom(msg.sender, _seller, _price);
          } else {
            revert("Please approve your Token to address this.");
          }
      }
      else if (msg.value >= _price) {
        payable(_seller).transfer(_price);
        uint256 extraPrice = msg.value - _price;
        if(extraPrice > 0){
          payable(msg.sender).transfer(extraPrice);
        }
      }
      else {
        revert("your payment is not enough to buy this NFT.");
      }
       
      // Transfer ownership 
      IERC721(_Nft).transferFrom(address(this), msg.sender, _id);
    
      // Update Auctiondata 
      dutchList[_ListNumber] = DutchList({
                  seller : payable(address(0)),
                  nft    : NFT({
                              Nft    : _Nft,
                              NftId  : _id,
                              payMent: address(0),
                              price  : 0
                          }),
                  startAt : 0,
                  EndAt   : 0,
            listedNumber  : 0,
                  isListed: false,
            discountRate : 0
      });
       
       // Index set to initialState
      ListNumber[_Nft][_id] = 0;
  }
  
  // This function show current DutchAuction NFT Price
  function DutchPrice(
    address _Nft,
    uint256 _id)
    public view returns(uint256) {
    
    // find index of NFT
    uint256 _ListNumber = ListNumber[_Nft][_id];
  
    // find NFT Item
    DutchList memory dutchItem = dutchList[_ListNumber];
    require(dutchItem.isListed, "This NFT is not listed.");
        // Calculate the Price of NFT
        uint timeElapsed = block.timestamp - dutchItem.startAt;
        uint discount = dutchItem.discountRate * timeElapsed;
        // return the price of NFT
        return dutchItem.nft.price - discount;
  }

  // If your NFT is not buy any one so you can refund your NFT
  function refundNft(address _Nft, uint256 _id) external {

     // find index 
     uint256 _ListNumber = ListNumber[_Nft][_id];
     // find list Item
     ListNft memory listItem = listNft[_ListNumber];
     
     // check NFT is Listed
     require(listItem.isListed, "This NFT is not on list.");
     // check NFT listing time is End or not
     require(block.timestamp > listItem.EndAt, "NFT is on sell.");
     
     // address seller
     address _seller = payable(listItem.seller);
     
     // Transfer NFT ownership
     IERC721(_Nft).transferFrom(address(this), _seller, _id);
     
     // Update NFT data
      listNft[_ListNumber] = ListNft({
            seller: payable(address(0)),
            nft  : NFT({
                      Nft: _Nft,
                      NftId: _id,
                      payMent: address(0),
                      price: 0
                  }),
            startAt : 0,
            EndAt   : 0,
            listedNumber : 0,
            isListed: false
        });
        
        // set index to initialState
        ListNumber[_Nft][_id] = 0;

      emit _refundNft(_Nft, _id, _seller);
  }

  
  function refundDutchNft(address _Nft, uint256 _id) external {

     // find index 
     uint256 _ListNumber = ListNumber[_Nft][_id];
     // find list Item
     DutchList memory dutchItem = dutchList[_ListNumber];
     
     // check NFT is Listed
     require(dutchItem.isListed, "This NFT is not on list.");
     // check NFT listing time is End or not
     require(block.timestamp > dutchItem.EndAt, "NFT is on sell.");
     
     // address seller
     address _seller = payable(dutchItem.seller);
     
     // Transfer NFT ownership
     IERC721(_Nft).transferFrom(address(this), _seller, _id);
     
     // Update NFT data
      dutchList[_ListNumber] = DutchList({
            seller: payable(address(0)),
            nft  : NFT({
                      Nft: _Nft,
                      NftId: _id,
                      payMent: address(0),
                      price: 0
                  }),
            startAt : 0,
            EndAt   : 0,
            listedNumber  : 0,
            isListed: false,
            discountRate : 0
        });
        
        // set index to initialState
        ListNumber[_Nft][_id] = 0;

      emit _refundNft(_Nft, _id, _seller);
  }

  // This function return only listed NFT.
  function getListNFT() public view returns(ListNft[] memory) {
    
    // count NFT
    uint itemCount;
    for (uint i=0; i<=ListOn; i++) 
    {
      if(listNft[i].isListed){
         itemCount += 1;
      }
    }

    // create memory array
    ListNft[] memory _listNFT = new ListNft[](itemCount);
     uint k;
    for (uint j=0; j<=ListOn; j++) 
    {
       // check is listed and if listed so push in _listNFT array
      if(listNft[j].isListed){
        k += 1;
         _listNFT[k - 1] = listNft[j];
      }
    }
     // return data of array
    return _listNFT;
  }


  // This function return only Auction NFT.
  function getDutchNFT() public view returns(DutchList[] memory) {

     // count NFT
    uint itemCount;
    for (uint i=0; i<=ListOn; i++) 
    {
      if(dutchList[i].isListed){
         itemCount += 1;
      }
    }

    // create memory array
    DutchList[] memory _dutchList = new DutchList[](itemCount);
     uint k;
    for (uint j=0; j<=ListOn; j++) 
    {
      // check is listed and if listed so push in _listNFT array
      if(dutchList[j].isListed){
        k += 1;
         _dutchList[k - 1] = dutchList[j];
      }
    }

    // return data of Array
    return _dutchList;
  }

}