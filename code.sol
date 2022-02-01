// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7; 

//Registration Smart contract

contract Registration {
    
    address public regulatory_authority; //Ethereum address of local regulator
    mapping(address => bool) public manufacturer; 
    mapping(address => bool) public distributor; 
    mapping(address => bool) public hospital; 

    //Registration Events
    
    event RegistrationSmartContractDeployer (address regulatory_authority); 
    event ManufacturerRegistered(address indexed regulatory_authority, address indexed manufacturer);
    event DistributorRegistered(address indexed regulatory_authority, address indexed distributor);
    event hospitalRegistered(address indexed regulatory_authority, address indexed hospital);

    //Modifiers
    
    modifier onlyregulatory_authority() {
        require(regulatory_authority == msg.sender, "Only the regulatory_authority is eligible to run this function");
        _;
    }
    
    constructor() {
        regulatory_authority = msg.sender;
        emit RegistrationSmartContractDeployer(regulatory_authority);
    }
    
    //Registration Functions
    function manufacturerRegistration (address user) public onlyregulatory_authority {
        require(manufacturer[user] == false, "The user is already registered");
        manufacturer[user] = true;   
    }
      function distributorRegistration (address user) public onlyregulatory_authority {
        require(distributor[user] == false, "The user is already registered");
        distributor[user] = true;
    }
    
    function hospitalRegistration (address user) public onlyregulatory_authority{
        require(hospital[user] == false, "The user is already registered");
        hospital[user] = true;
    } 
}
contract LotProductionCommitment {
 Registration public reg_contract; 
 bytes32 public MedicalSupplyType;
 uint public StartingTime;
 uint public MinThreshold;
 uint public CommitmentDuration; 
 uint public MaxPackages;  
 mapping(address => bool) public Distributor_Committed; 
 address public CommittedDistributor; 
 bool public DistributorCommitted;
 mapping(address => HospitalChoice) public HospitalAffiliation; 
 struct HospitalChoice{
 address a_distributor; 
 bool Affiliated; 
 }
 uint PlacedBidsCounter = 0; 
 uint public CurrentBids;
 uint public BiddersCounter = 0; 
 address[] public Bidders; 
 mapping(address => bool) public BidderCommitted; 
 mapping(address => uint) public BidderAmount; 
 bool public ProductionPermission; 
 bool public manufactured; 
 uint public currentLotstate;
 uint public expirydate;
 uint public deliveryduration; 
 uint public Packages;
 address public CommittedManufacturer;

 event CommitmentDetails (address indexed _manufacturer, address indexed _LotEA, bytes32 _MedicalSupplyType, uint _MaxPackages,
 uint _MinThreshold, uint _StartingTime, uint _CommitmentDuration);
 event DistributorCommitmentDetails(address indexed _distributor, address indexed _LotEA);
 event hospitalCommitmentDetails(address indexed hospital, address indexed _LotEA, uint _placedorder);
 event Thetimewindowisend(address indexed _msgsender, bytes32 _windowclosed);
 event ProductionApproved(bytes32 _approved, uint _currentbids, address indexed _vaccineLotEA);
 event ProductionRejected(bytes32 _denied, uint _currentbids, address indexed _vaccineLotEA);
 event LotProduced(address indexed _manufacturer, address indexed _LotEA, bytes32 _MedicalSupplyType,
 uint _currentbids, uint _productionTime, uint _deliveryduration, uint _expirydate); 

    modifier onlyhospital{
    require(reg_contract.hospital(msg.sender), "Only the hospital is allowed to execute this function");
    _;
    }
    
    modifier onlymanufacturer{
    require(reg_contract.manufacturer(msg.sender), "Only the manufacturer is allowed to execute this function");
    _;
    }
    
    modifier onlyDistributor{
    require(reg_contract.distributor(msg.sender), "Only the distributor is allowed to execute this function");
    _;
    }

    constructor(address RegistrationSCaddress, uint _MinThreshold, uint _MaxPackages, string memory _MedicalSupplyType, uint _CommitmentDuration) {
        reg_contract = Registration(RegistrationSCaddress);
        MinThreshold = _MinThreshold;
        MaxPackages = _MaxPackages;
        MedicalSupplyType = bytes32(bytes(_MedicalSupplyType));
        CommitmentDuration =  _CommitmentDuration * 1 minutes; 
        StartingTime = block.timestamp;
        CommittedManufacturer = msg.sender;
        emit CommitmentDetails(msg.sender, address(this), MedicalSupplyType, MaxPackages, MinThreshold, StartingTime, CommitmentDuration);
    } 
    
    function DistributorCommitment() public onlyDistributor{
        require(block.timestamp <= StartingTime + CommitmentDuration, "The time window is end: any new commitment is not accepted ");
        require(DistributorCommitted == false, "The Lot has already been committed to by another distributor ");
        Distributor_Committed[msg.sender] = true; 
        DistributorCommitted =true;
        CommittedDistributor = msg.sender;
        emit DistributorCommitmentDetails(msg.sender, address(this));  
    }
    function AddingAffiliatedDistributor (address _distributor) public onlyhospital{ 
        require(!HospitalAffiliation[msg.sender].Affiliated, "This hospital has already an affiliated distributor");
        HospitalAffiliation [msg.sender].a_distributor = _distributor;
        HospitalAffiliation [msg.sender].Affiliated = true;
    }
     function PlaceBid(uint _PlacedBid) public onlyhospital{
        require(block.timestamp <= StartingTime + CommitmentDuration , "The time window is end: any new Bid is not accepted");
        require(Distributor_Committed[HospitalAffiliation[msg.sender].a_distributor], "The affiliated distributor with this hospital has not committed to deliver this Lot");
        require(_PlacedBid + PlacedBidsCounter <= MaxPackages, "The specified amount exceeds the maximum or the remaining number of packages within the Lot");
        require(!BidderCommitted[msg.sender], "This hospital has already placed a bid before");
        PlacedBidsCounter += _PlacedBid;
        CurrentBids = PlacedBidsCounter; 
        Bidders.push(msg.sender);
        BidderCommitted[msg.sender] = true; 
        BidderAmount[msg.sender] = _PlacedBid; 
        BiddersCounter += 1; 

        if(CurrentBids == MaxPackages){
            emit hospitalCommitmentDetails(msg.sender, address(this), _PlacedBid);
            emit Thetimewindowisend (msg.sender, bytes32("Commitment Window is now closed"));
            emit ProductionApproved(bytes32("Production is approved"), CurrentBids, address(this));
            ProductionPermission = true;
             }
            else {
            emit hospitalCommitmentDetails(msg.sender, address(this), _PlacedBid);
        }
        
           
    }
    function EndCommitmentTime() public onlymanufacturer{
        require(block.timestamp == StartingTime + CommitmentDuration , "There is still time left");
        if(CurrentBids < MinThreshold){
             emit ProductionRejected(bytes32("Production is rejected"), CurrentBids, address(this));
            ProductionPermission = false;
             }
            else if (CurrentBids >= MinThreshold) {
                emit hospitalCommitmentDetails(msg.sender, address(this), CurrentBids);
                emit ProductionApproved(bytes32("Production is approved"), CurrentBids, address(this));
            ProductionPermission = true;

            }
        }
        function LotProduction(uint _expirydurationinmonths, uint _deliverydurationindays, uint _Packages) public onlymanufacturer{
        require(ProductionPermission == true, "The manufacturer does not have permission to produce the  Lot");
        require(manufactured == false, "This Lot has already been manufactured");
        manufactured = true;        
        expirydate = block.timestamp + (_expirydurationinmonths * 30 days);
        deliveryduration = block.timestamp + (_deliverydurationindays * 1 days);
        Packages = _Packages;
        emit LotProduced(msg.sender, address(this), MedicalSupplyType, Packages, block.timestamp, deliveryduration, expirydate);
    }

    }

contract DelivaryAndConsumption {
    Registration public reg_contract; 
    LotProductionCommitment public PC_contract; 
    address public LotEA; 
    uint public expirydate;
    uint public deliveryduration; 
    bytes32 public MedicalSupplyType; 
    uint DeliveredPackagesCounter = 0;
    uint public CurrentDeliveredPackages;
    uint ReceivedPackagesCounter = 0;
    uint public CurrentReceivedPackages;
    mapping(address => bool) public ReceptionConfirmation; //Used to check if the healthcare center received their committed amount or not
    mapping(address => uint) public ReceivedAmount; //Used to track how much each healthcare center received
    enum  LotState  {NotManufactured, EnRoute, Delivered}
    LotState public Lotstate;
    mapping(address => uint) public usedAmount;
    mapping(address => uint) public wastedAmount;

    event StartDelivery (address indexed _distributor, address indexed _LotEA, uint _StartingTime);
    event ConfirmReception (address indexed _hospital, address indexed _LotEA, uint _receivedpackages, uint _ReceptionTime);
    event ConfirmDelivery (address indexed _distributor, address indexed _LotEA, address indexed _hospital, uint _deliveredPackages, uint _DeliveryTime); 
    event EndDelivery (address indexed _distributor, address indexed _LotEA, uint _vaccinePackagesDelivered, uint _EndingTime); 
    event PackagesUsed(address indexed _hospital, uint _Amountused, uint _DateofUse);
    event PackagesDisposed(address indexed _hospital, uint _disposedAmount, uint _DateofDisposal);

    modifier onlyhospital{
    require(reg_contract.hospital(msg.sender), "Only the hospital is allowed to execute this function");
    _;
    }
    modifier onlymanufacturer{
    require(reg_contract.manufacturer(msg.sender), "Only the manufacturer is allowed to execute this function");
    _;
    }
    modifier onlyDistributor{
    require(reg_contract.distributor(msg.sender), "Only the distributor is allowed to execute this function");
    _;
    }
 constructor(address registractionSC, address LotProductionCommitmentSC) {
    reg_contract = Registration(registractionSC);
    PC_contract = LotProductionCommitment(LotProductionCommitmentSC);
    LotEA = LotProductionCommitmentSC;
    }
 function startDelivery() public onlyDistributor{
        require(PC_contract.manufactured() == true, "This Lot has either already been delivered or not manufactured yet");
        Lotstate = LotState.EnRoute;
        emit StartDelivery (msg.sender, LotEA, block.timestamp);
    }
 function ConfirmationofReception(uint _receivedpackages) public onlyhospital{
        require(Lotstate == LotState.EnRoute, "Can't confirm Lot reception as it is not out for delivery yet");
        require(PC_contract.BidderCommitted(msg.sender), "This hospital has not committed and therefore cannot receive the packages");
        require(!ReceptionConfirmation[msg.sender],"This hospital has already confirmed receiving their packages");
        require(_receivedpackages == PC_contract.BidderAmount(msg.sender), "Can't confrim reception because the number of packages does not equal the bidder's committed amount");
        ReceptionConfirmation[msg.sender] = true; 
        ReceivedAmount[msg.sender] = _receivedpackages; 
        emit ConfirmReception(msg.sender, LotEA, _receivedpackages, block.timestamp);
    }
    function ConfirmationofDelivery(address _hospital, uint _deliveredPackages) public onlyDistributor{ 
        require(_deliveredPackages == PC_contract.BidderAmount(_hospital), "Can't confrim delivery because the number of packages does not equal the bidder's committed amount");
        require(Lotstate == LotState.EnRoute, "Can't confirm Lot delivery as it is not out for delivery yet or has already been delivered");
        require(PC_contract.Distributor_Committed(msg.sender), "Only a committed distributor is allowed to deliver packages to hospital");
        require(ReceptionConfirmation[_hospital],"The healthcare center has not confirmed receiving the packages");
        DeliveredPackagesCounter += _deliveredPackages;
        CurrentDeliveredPackages = DeliveredPackagesCounter;
        if(CurrentDeliveredPackages == PC_contract.CurrentBids()){
            Lotstate = LotState.Delivered; 
            emit ConfirmDelivery(msg.sender, LotEA,_hospital, _deliveredPackages, block.timestamp); 
            emit EndDelivery(msg.sender, LotEA, CurrentDeliveredPackages, block.timestamp); 
            
        }
    }
 function UsePackages(uint _usedpackages) public onlyhospital{
        require(PC_contract.BidderCommitted(msg.sender), "The executor of this function needs to be a committed bidder");
        require(_usedpackages + usedAmount[msg.sender] + wastedAmount[msg.sender] <= ReceivedAmount[msg.sender]);
        usedAmount[msg.sender] += _usedpackages; 
        emit PackagesUsed(msg.sender, _usedpackages, block.timestamp);
    }
 function DisposePackages(uint _disposedPackages) public onlyhospital{
        require(_disposedPackages + usedAmount[msg.sender] + wastedAmount[msg.sender] <= ReceivedAmount[msg.sender]);
        wastedAmount[msg.sender] += _disposedPackages; 
        emit PackagesDisposed(msg.sender, _disposedPackages, block.timestamp);
    }
}
contract WasteAssessment {

    Registration public reg_contract2; 
    LotProductionCommitment public PC_contract2; 
    DelivaryAndConsumption public DC_contract;
    uint public missingAmount;
    uint public unusedAmount;
    uint public OverProducedAmount;
    uint public ViolationCounter =0; 

    event DistributorViolation(address _distributor, bytes32 _msg, uint _missingAmount);
    event HospitalViolation(address _hospital, bytes32 _msg, uint _unusedAmount);
    event ManufacturerViolation(address _manufacturer, bytes32 _msg, uint _excessAmount);
    event NoViolation(address _manufacturer, bytes32 _msg);
    modifier onlyregulatory_authority() {
    require(reg_contract2.regulatory_authority() ==msg.sender, "Only the regulatory_authority is eligible to run this function");
    _;
    }
    constructor(address registrationSC, address LotProductionCommitmentSC, address DelivaryAndConsumptionSC){
        reg_contract2 = Registration(registrationSC);
        PC_contract2 = LotProductionCommitment(LotProductionCommitmentSC);
        DC_contract = DelivaryAndConsumption(DelivaryAndConsumptionSC);
    }
    
    function ViolationCheck() public onlyregulatory_authority {
        if (PC_contract2.Packages() > PC_contract2.CurrentBids()) {
            OverProducedAmount = PC_contract2.Packages() - PC_contract2.CurrentBids();
            ViolationCounter +=1;
             emit ManufacturerViolation(PC_contract2.CommittedManufacturer(), bytes32("Excess Amount Produced"), OverProducedAmount);
        }
        if(DC_contract.CurrentDeliveredPackages() < PC_contract2.Packages()){
            missingAmount = PC_contract2.Packages() - DC_contract.CurrentDeliveredPackages();
            ViolationCounter +=1;
            emit DistributorViolation(PC_contract2.CommittedDistributor(), bytes32("Distributor Failed To Deliver"), missingAmount);
        }

        for(uint i = 0; i < PC_contract2.BiddersCounter(); i++){
            if( DC_contract.usedAmount(PC_contract2.Bidders(i)) <PC_contract2.BidderAmount(PC_contract2.Bidders(i))){
                unusedAmount = PC_contract2.BidderAmount(PC_contract2.Bidders(i)) - DC_contract.usedAmount(PC_contract2.Bidders(i));
                ViolationCounter +=1;
                emit HospitalViolation(PC_contract2.Bidders(i), bytes32("Hospital failed to consume"), unusedAmount);
            } else if(DC_contract.wastedAmount(PC_contract2.Bidders(i)) > 0){
                   ViolationCounter +=1;
                emit HospitalViolation(PC_contract2.Bidders(i), bytes32("Hospital wasted Medical Supplies"), DC_contract.wastedAmount(PC_contract2.Bidders(i)));
            }
        }
        if (   ViolationCounter ==0){
            emit NoViolation(msg.sender, bytes32("Lot is consumed properly"));
        }
    }
}
