//SPDX-License-Identifier:MIT
pragma solidity ^0.8.8;

//取得方法：https://docs.chain.link/docs/get-the-latest-price/
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";

error FundMe__NotOwner();

/**@title A contract for crowd funding
 *
 */
contract FundMe {
    // Type declarations
    using PriceConverter for uint256;
    //constant:21438gas
    //non-constant: 23538gas
    //constantを使うことでストレージではなくコントラクトのバイトコードに格納するのでgasを節約する
    //State variables
    uint256 public constant MINIMUM_USD = 50 * 1e18;
    AggregatorV3Interface private s_priceFeed;
    address[] private s_funders;
    mapping(address => uint256) private s_addressToAmountFunded;
    //immutableを使うことでストレージではなくコントラクトのバイトコードに格納するのでgasを節約する
    address private immutable i_owner;

    //modifier
    modifier onlyOwner() {
        // require(msg.sender==i_owner,"Sender is not owner!");
        //文字列を使わないのでgasを節約できる
        if (msg.sender != i_owner) {
            revert FundMe__NotOwner();
        }
        _; //呼び出し元functionを実行
    }

    //constructor
    //receive
    //fallback
    //external
    //public
    //internal
    //private
    //view/pure
    constructor(address priceFeedAddress) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    //fund functionの呼出しなしでこのコントラクトにETHを送った場合何が起きる？
    //solidityではコントラクトにETHを送った場合の挙動を実装する2つの特殊な関数がある
    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    //Eth is sent to contract
    //   is msg.data empty?
    //     /              \
    //   yes               no
    //   /                  \
    // receive()は実装済？   fallback()
    //   /       \
    //  yes      no
    //  /         \
    // receive() fallback()
    function fund() public payable {
        //want to be able to set a minimum fund amount in USD
        //1e18=1*10**18
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "Didn't send enough ether"
        );
        s_funders.push(msg.sender);
        s_addressToAmountFunded[msg.sender] = msg.value;
    }

    function withdraw() public onlyOwner {
        for (
            uint256 funderIndex = 0;
            funderIndex < s_funders.length;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        //reset array
        s_funders = new address[](0);

        //actually withdraw the fund

        //transfer
        //msg.senderのtype：address
        //payable(msg.sender):payable address
        // //solidityではpayable addressのみnative tokenの送金可能
        // payable(msg.sender).transfer(address(this).balance);
        //send
        // //requireを使うことでエラー発生時処理を戻すことが出来る
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "Send Failed");

        //call
        //任意の関数を呼ぶことが出来る？
        //bytes型の変数を受け取ることもできる
        // (bool callSuccess,bytes dataReturned)=payable(msg.sender).call{value:address(this).balance}("");
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call Failed");
    }

    function cheaperWithdraw() public onlyOwner {
        address[] memory funders = s_funders;
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        //reset array
        s_funders = new address[](0);

        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call Failed");
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }

    function getFunder(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    function getAddressToAmountFunded(address funder)
        public
        view
        returns (uint256)
    {
        return s_addressToAmountFunded[funder];
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }
}
