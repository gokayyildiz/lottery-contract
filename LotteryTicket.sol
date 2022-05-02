// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./TurkishLira.sol";

contract LotteryTicket is ERC721, Ownable {

    mapping(uint256 => address) public ticket_owner; // maps the tickets to the owner address, to check the operation is called by the owner afterwards

    mapping(uint256 => uint) public random_number_hash_ticket; // pairs the tickets with the random number hashes that is assigned while minting the ticket

    mapping(uint256 => bool) public is_ticket_revealed; // checks if the ticket is revealed or not to determine if this ticket can get reward or not

    mapping(uint256 => bool) public is_ticket_refunded; // checks if the ticket is refunded or not to determine if this ticket can get refund or not

    mapping (address => uint) public tlBalance; // lottery'ye giricek kullanıcıların adresleri hesaplarındaki tl miktarı ile eşleştirilmiş durumda

    uint256 lotteryId; // to follow which lottery it is 

    mapping (uint256 => uint[]) public ticket_nos_in_lottery ; // given key: lottery id , value: array of ticket id's of the tickets joining the given lottery

    TurkishLira public tl; // to use our erc20 token


    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("LotteryTicket", "LTK") {
        lotteryId = 1;
        // should be the address of the TurkishLira token's active address
        tl = TurkishLira(0xD8555E9A128C07928C1429D834640372C8381828);
    }


    // we are depositing tl token from caller account to the contracts address, we keep real tokens on contracts balance
    // we just keep the amounts in a mapping to caller address and amount of the caller's account symbolically
    // we need to approve the address of the contract from outside, approving inside the contract does not allowed. 
    function depositTL(uint amnt) public payable  { // payable silinebilir denemedim
        require(tl.balanceOf(msg.sender) >= amnt * 10 ** tl.decimals());

        //tl.approve(address(this), amnt); // bunu dışardan yapmak lazım burda çalışmıyor
        tl.transferFrom(msg.sender, address(this), amnt* 10 ** tl.decimals());

        tlBalance[msg.sender] += amnt; 

        
    }

    // we decrease the amound withdrawn from the TlBalance as value and transfer the tokens from smart contracts address to
    // callers address
    function withdrawTL(uint amnt) public  {
        // control if the given address exists in the tlBalance map // bu belki gerekmez !?!?!
    //    require(); // yukardaki koşulu eklersek içi dolacak

        // control if the balance of the given address is greater than the withdraw amount
        require(tlBalance[msg.sender] >= amnt);
        // burda bir şekilde transferi yaptırmak lazım bu aşağıdaki şekilde onaylamıyor, allowance sıkıntısı veriyor
        tlBalance[msg.sender] -= amnt;

        tl.approve(msg.sender, amnt * 10 ** tl.decimals());
        tl.transfer(msg.sender, amnt * 10 ** tl.decimals());
    
    }

    function safeMint(address to) private returns(uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        return tokenId;
    }

    /*
    * Her bilet aldığımızda bir nft mint edilir ve bu unique tokenId'si hash_rnd_number ile eşleştirilir
    */
    function buyTicket(uint hash_rnd_number) public {
        // burda 10 lira hesabında var mı diye kontrol ediyoruz
        
        require(tlBalance[msg.sender] >= 10);
        tlBalance[msg.sender] -= 10;

        // erc721 mint işlemi gerçekleştiriliyor
        uint256 tokenId = safeMint(msg.sender);
        // burda sonrasında kullanmak için yukarıda amaçlarını anlattığım dictionarilere atamalar yapıyoruz
        ticket_owner[tokenId] = msg.sender;
        random_number_hash_ticket[tokenId] = hash_rnd_number;
        is_ticket_revealed[tokenId] = false;
        is_ticket_refunded[tokenId] = false;
        ticket_nos_in_lottery[lotteryId].push(tokenId);
       
        
    }

    function collectTicketRefund(uint ticket_no) public {
        // refund isteyen biletin sahibi mi kontrolü
        require(ticket_owner[ticket_no] == msg.sender);

        // burda reveal edilmemişler refund edilmiş mi gibi bir şey tutabiliriz birden çok kez refund edilmesinler diye 
        // burda o parametreyi de güncelleriz refund edilmiş olarak
        require(is_ticket_refunded[ticket_no] == false);
        // burda reveal etmiş mi etmemiş mi diye bakacağız
        // refund collect edebilmesi için reveal etmemiş olması lazım
        require(is_ticket_revealed[ticket_no] == false);

        // burda true'ya çeviriyoruz
        is_ticket_refunded[ticket_no] = true;

        // eger requirelar gecerse biletin yarı parasını iade ediyoruz
        tlBalance[msg.sender] += 5;



    }


    // burda verilen ticket no ile owner addresi bulmamız gerekiyor
    function revealRndNumber(uint ticketno, uint rnd_number) public {
        //address ownerAddress = ticket_owner[ticketno];
        // bu adres ile random number'ı birlikte hashleyip kayıtlı hash ile eşleşiyor mu diye bakacağız

        require(random_number_hash_ticket[ticketno] == rnd_number);

        is_ticket_revealed[ticketno] = true;
    }


}