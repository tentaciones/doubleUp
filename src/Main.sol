pragma solidity 0.8.17; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./VRFv2Consumer.sol";



contract Main {

    uint256 public gameId;
    uint256 public potId=1;
    uint public potReqId;
    uint public fees;
    bool public firstPotNotCreated;

    address payable public immutable owner;
    VRFv2Consumer public immutable VRFv2ConsumerOf;
    

    struct DATUM{
        uint _id;
        string _name;
        uint _amount;
        uint _time;
        address _creator;
        address lastPlayer;
        bool _claimed;
        
    }

    struct THEM{
        string _name;
        uint _amount;
        address _them;
    }

    struct THEPOT{
        uint _id;
        uint _amount;
        uint _mineNumber;
        uint _timePeriod;
        address _yoursTruly;
        bool isPotInit;

        
    }

    DATUM [] public data;
    THEM [] public them;
    THEPOT []public thePot;

    uint fMa=5;



    mapping (uint=>DATUM)public idToDatum;
    mapping(uint=>THEPOT) public idToPot;
    mapping (address=>uint) public userReqId;

    event created(address creator, string name,uint _time);
    event doubled(address doubler, uint id, string name, uint newAmount, uint timeRemainder);
    event claimed (address claimer, uint amount, uint id);
    event those (address claimer, uint amount, uint id);
    event createdPot(uint potId, uint mineNumber);

    
    constructor(address payable _owner, VRFv2Consumer _VRFv2ConsumerOf) {
        owner=_owner;
        VRFv2ConsumerOf=_VRFv2ConsumerOf;
       
    }

       modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }

    function createNew(string calldata _name, uint _time) external payable{
        require(_time> block.timestamp,"invalid time");
        require(msg.value>0, "0 amount");
        uint amount=calc(msg.value);
        (bool success,)=address(this).call{value:amount}("");
        require (success, "create fail");

        DATUM storage s_data = idToDatum[gameId];
        s_data._amount=amount;
        s_data._creator=msg.sender;
        s_data._id=gameId;
        s_data._name=_name;
        s_data._time=block.timestamp;
        s_data.lastPlayer=msg.sender;
        s_data._claimed=false;
        data.push(DATUM({_id:gameId, _name:_name, _amount:amount, _time:block.timestamp, _creator:msg.sender, lastPlayer:msg.sender,_claimed:false}));

        gameId++;

        emit created (msg.sender, _name, _time);

    }

    function double(uint _id) external payable{
        DATUM storage s_data = idToDatum[_id];
        uint time=s_data._time;
        require (block.timestamp>time, "expired");

        uint prevBalance=s_data._amount;
        uint doubleUp=prevBalance*2;
        require (msg.value>=doubleUp,"doubleUp");
        uint amount=calc(doubleUp);
        (bool success,)=address(this).call{value:amount}("");
        require (success, "double fail");
        s_data._amount=amount;
        s_data.lastPlayer=msg.sender;

        emit doubled(msg.sender, _id, s_data._name,amount, 1);

    }

    function theOnes(uint _id) external payable{
        
        DATUM storage s_data = idToDatum[_id];
        require (block.timestamp<s_data._time, "cant");
        require (!s_data._claimed,"claimed");
        uint amount=s_data._amount;
        s_data._amount=0;


        for (uint i; i<data.length; i++){
            DATUM memory m_data= data[i];
            if(m_data._id==_id){
                data[i] = data[data.length - 1];
                data.pop();
                  
            }

        }
        uint amountT=calc(amount);
        (bool success,)=address(payable(msg.sender)).call{value:amountT}("");
        require (success, " fail");
        s_data._claimed=true;
        them.push(THEM({_name:s_data._name,_amount:amount, _them:msg.sender}));
        emit those(msg.sender, amount, _id);

    }


    function claim (uint _id) external payable{
        DATUM storage s_data = idToDatum[_id];
        require (!s_data._claimed,"claimed");
        

        if(msg.sender==s_data._creator){
            require (block.timestamp>s_data._time+ 3 days, "cant");
            uint amount=s_data._amount;
            s_data._amount=0;
            
            for (uint i; i<data.length; i++){
                DATUM memory m_data= data[i];
                if(m_data._id==_id){
                    data[i] = data[data.length - 1];
                    data.pop();
                  
                }

            }

            uint amountT=calc(amount);

            (bool success,)=address(payable(msg.sender)).call{value:amountT}("");
            require (success, "claim fail");
            s_data._claimed=true;
            emit claimed(msg.sender, amount, _id);

        }else if(msg.sender==s_data.lastPlayer ){
            require (block.timestamp+3 days>s_data._time, "now creators");
            uint amount=s_data._amount;
            s_data._amount=0;
            
            for (uint i; i<data.length; i++){
                DATUM memory m_data= data[i];
                if(m_data._id==_id){
                    data[i] = data[data.length - 1];
                    data.pop();
                  
                }

            }
             uint amountT=calc(amount);
            (bool success,)=address(payable(msg.sender)).call{value:amountT}("");
            require (success, "claim fail");
            s_data._claimed=true;
            emit claimed(msg.sender, amount, _id);
        }
        
      

    }

    function initialPot()public  payable onlyOwner returns (uint amount){
        require(firstPotNotCreated, "cant");
        newPot();
        firstPotNotCreated=true;
        amount=msg.value;


    }

    function newPot() internal {
        potReqId=VRFv2ConsumerOf.requestRandomWords();
        THEPOT storage s_pot=idToPot[potId];
        s_pot._amount=1;
        s_pot._id=potId;
        s_pot._yoursTruly=address(0);
        s_pot._mineNumber=0;
        s_pot.isPotInit=false;
        s_pot._timePeriod=block.timestamp;
        thePot.push(THEPOT({_amount:1, _id:potId,_yoursTruly:address(0), _mineNumber:0 , isPotInit:false, _timePeriod:block.timestamp}));
        potId++;

        emit createdPot(s_pot._id, s_pot._mineNumber);
    }

    function stirPot()payable external{
        require (potId!=0,"0 potId" );
        THEPOT storage s_pot=idToPot[potId-1];

        (,uint [] memory word)=VRFv2ConsumerOf.getRequestStatus(potReqId);
        
        s_pot._mineNumber=word[0]%1000;
        if (block.timestamp>s_pot._timePeriod+ 30 days &&s_pot._amount>0){
            uint amount=s_pot._amount/2;
            uint amountT=calc(amount);
            (bool success,)=address(payable(this)).call{value:amountT}("");
            require (success, "stir fail"); 
            s_pot._timePeriod=block.timestamp;
        }else{
            uint amount=s_pot._amount*2;   
            uint amountT=calc(amount);
            (bool success,)=address(payable(this)).call{value:amountT}("");
            require (success, "stir fail"); 

        }

        userReqId[msg.sender]=VRFv2ConsumerOf.requestRandomWords();
        s_pot.isPotInit=true;

    }

    function checkPot ()payable external returns (bool won){
        THEPOT storage s_pot=idToPot[potId-1];
        require (s_pot.isPotInit, "not init");
        (,uint [] memory iMined)=VRFv2ConsumerOf.getRequestStatus(userReqId[msg.sender]);
        if (s_pot._mineNumber==iMined[0]%5000){
            uint amountT=calc(s_pot._amount);
            (bool success,)=address(payable(msg.sender)).call{value:amountT-1}("");
            require (success, "stir fail");
            won=true;
            newPot();
        }else{
            won =false;
        }


    }

    function calc(uint _amount) public  returns (uint){
        uint fee= fMa*_amount/100;
        fees+=fee;
        return _amount-fee;
    }

    function  donate() payable external{
        require(msg.value>0, "0 amount");
        (bool success,)=owner.call{value:msg.value}("");
        require (success, "donation fail");

    }

    function claimFee()external onlyOwner{
        (bool success,)=owner.call{value:fees}("");
        require (success, "claim fail");
    }

    function updateFma(uint _newFMa) external onlyOwner returns (uint){
        fMa=_newFMa;
        return fMa;
    }

    function getAll()public view returns (DATUM []memory){
        return data;
    }

    function randomBalance (IERC20 _address) public view  returns (uint){
       return  _address.balanceOf(address(this));

    }

    function tRandom(IERC20 _address, address _to) external onlyOwner{
        uint amount=_address.balanceOf(address(this));
        _address.transfer( _to,amount);
    }


    function cc(uint a)public view returns (string memory c){
        {a>block.timestamp? c="a is greater":c="b is greater";}
    }

    function timetester(uint add) public  view returns (uint){
        return add+block.timestamp;
    }

    function getCurrentAmountToStirPot()public view returns (uint toPot){
        THEPOT storage s_pot=idToPot[potId-1];
        if (block.timestamp>s_pot._timePeriod+ 30 days &&s_pot._amount>0){
            toPot=s_pot._amount/2;

        }else{
       toPot=s_pot._amount*2;

        }

  

    }

    receive ()external payable{

    }

}