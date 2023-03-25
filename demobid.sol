//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Valuation {
    // Cấu trúc của 1 User
    struct User {
        bool registered;
        string name;
        uint userDeviation;
        uint sessionJoined;
    }
    // Cấu trúc của 1 product
    struct Product {
        bytes32 productHash;
        string ipfs;
        bool exists;
        bool haveFinalPrice;
        bool inValuation;
        uint finalPrice;
        string name;
        uint evaluatorsCount;
        uint[] prices;
        address[] evaluators;
        uint timeEnd;
    }

    mapping(address => User) public users;
    mapping(bytes32 => Product) public products;

    address public administrator;
    uint public productCount;
    uint public numberOfProductInValuation;
    mapping(uint => bytes32) public productArray;

    // Chỉ có một quản trị viên.
    constructor() {
        administrator = msg.sender;
    }
    // Người tham gia phải đăng ký để sử dụng ứng dụng.
    function register(string memory name) public {
        require(!users[msg.sender].registered, "User already registered");
        require(bytes(name).length > 0, "your name, pls"); //yêu cầu không để trống tên
        uint userDeviation = 0;
        uint sessionJoined = 0;
        users[msg.sender] = User(true, name, userDeviation, sessionJoined);
    }

    // Chỉ quản trị viên mới có thể tạo sản phẩm.
    function createProduct(bytes32 productHash, string memory name, string memory ipfs) public {
        require(msg.sender == administrator, "Only administrator can create product");
        require(!products[productHash].exists, "Product already exists");
        bool exists = true;
        bool haveFinalPrice = false;
        bool inValuation = false;
        uint finalPrice = 0;
        uint evaluatorsCount = 0;
        uint[] memory _prices;
        address[] memory _evaluators;
        products[productHash] = Product(productHash, ipfs, exists, haveFinalPrice, inValuation, finalPrice, name, evaluatorsCount,  _prices, _evaluators, 0);
        productArray[productCount] = productHash;
        productCount ++;
    }

    // Chỉ quản trị viên mới có thể tạo phiên định giá.
    function createValuation(bytes32 productHash, uint timeSet) public {
        require(msg.sender == administrator, "Only administrator can create Valuation");
        require(products[productHash].exists, "Product does not exist");
        require(!products[productHash].inValuation, "Product still in valuation");
        products[productHash].inValuation = true;
        numberOfProductInValuation ++;
        if(timeSet != 0) {
            products[productHash].timeEnd = block.timestamp + timeSet;
        }
    }

    /* Một người tham gia có thể định giá nhiều hơn một sản phẩm nếu phiên vẫn mở. 
    Giá đưa ra mới nhất sẽ được sử dụng. */
    function addPrice(bytes32 productHash, uint price) public {
        require(users[msg.sender].registered, "User not registered");
        require(products[productHash].exists, "Product does not exist");
        require(products[productHash].inValuation, "Product must in valuation");
        require(block.timestamp < products[productHash].timeEnd || products[productHash].timeEnd == 0, "Valuation period has ended");
        bool check = false;
        for (uint j = 0; j < products[productHash].evaluatorsCount; j++){
            if(msg.sender == products[productHash].evaluators[j]){
                products[productHash].prices[j] = price;
                check = true;
                break;
            }         
        }
        if(!check) {
            products[productHash].evaluatorsCount ++;
            products[productHash].evaluators.push(msg.sender);
            products[productHash].prices.push(price);
            users[msg.sender].sessionJoined ++;
        }
    }

    /*Giá đề xuất cho một sản phẩm sẽ được tính toán dựa trên tất cả các mức giá đã cho trong 
    phiên và độ lệch chung của người tham gia.*/
    function caculateFinalPrice(bytes32 productHash) public returns (uint finalPrice) {
        require(msg.sender == administrator, "Only administrator can caculate final price");
        require(products[productHash].exists, "Product does not exist");
        require(products[productHash].inValuation, "no valuation for this product");
        uint A = 0;
        uint B = 0;
        for (uint j = 0; j < products[productHash].evaluatorsCount; j++){
            A += products[productHash].prices[j] * (100 - users[products[productHash].evaluators[j]].userDeviation);
            B += users[products[productHash].evaluators[j]].userDeviation; 
        }
        products[productHash].finalPrice = (A) / (100 * products[productHash].evaluatorsCount - B);
        finalPrice = (A) / (100 * products[productHash].evaluatorsCount - B);
    }
/*Ứng dụng duy trì một giá trị độ lệch chung cho mỗi người tham gia. Độ lệch chung được 
    tích lũy từ độ lệch giữa giá nhất định của anh ấy và giá cuối cùng từ mỗi phiên định giá.*/
    function newUserDeviation(bytes32 productHash) private {
        uint P = products[productHash].finalPrice;      
        for (uint j = 0; j < products[productHash].evaluatorsCount; j++){
            uint dNew;
            uint d;
            uint dCurrent = users[products[productHash].evaluators[j]].userDeviation;
            uint n = users[products[productHash].evaluators[j]].sessionJoined;
            if(products[productHash].prices[j] < P){
                dNew = P - products[productHash].prices[j];
            }
            else{
                dNew = products[productHash].prices[j] - P;
            }
            uint dNew1 = (dNew * 100) / P;
            d = (dCurrent * n + dNew1) / (n + 1);
            users[products[productHash].evaluators[j]].userDeviation = d;
        }
    }

    // Chỉ quản trị viên mới có thể đóng phiên định giá.
    function closeValuation(bytes32 productHash) public {
        require(msg.sender == administrator, "Only administrator can close valuation!");
        require(products[productHash].exists, "Product does not exist!");
        require(products[productHash].inValuation, "no valuation for this product!");
        // thêm yêu cầu tính giá cuối cùng trước khi đóng phiên
        require(products[productHash].finalPrice != 0, "Pls caculate finalPrice before close the valuation!");
        newUserDeviation(productHash);
        products[productHash].inValuation = false;
        numberOfProductInValuation --;
    }
    
    // Hàm check admin. (Dư)
    function isAdministrator(address account) public view returns (bool) {
        return account == administrator;
    }

    // Hàm lấy sản phẩm đang định giá theo thứ tự
    function getProdInValByID(uint id) public view returns (bytes32 _hash){
        require(numberOfProductInValuation > 0, "No product in valuation");
        uint temp = 0;
        for(uint j = 0; j < productCount; j++){
            if (products[productArray[j]].inValuation) {
                if (temp == id) {
                    _hash = productArray[j];
                    //_name = products[productArray[j]].name;
                } 
                temp++;
            }
        }
    }

    function getValuator(bytes32 productHash, uint id) public view returns (string memory _name, uint _price, address _address) {
        // require(numberOfProductInValuation > 0, "No product in valuation");
        require(products[productHash].evaluatorsCount > id, "No evaluation with that id");
        _name = users[products[productHash].evaluators[id]].name;
        _price = products[productHash].prices[id];
        _address = products[productHash].evaluators[id];
    }
}