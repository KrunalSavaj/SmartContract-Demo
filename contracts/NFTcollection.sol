// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract NFTcollection is ERC721("Swaminarayan" , "SWA") {

    uint256 tokenId;

    function mint() public {
        tokenId++;
         _mint(msg.sender, tokenId);
    }
}





