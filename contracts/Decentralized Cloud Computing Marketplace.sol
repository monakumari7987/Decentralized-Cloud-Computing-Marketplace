// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Cloud Computing Marketplace
 * @dev A smart contract for peer-to-peer cloud computing resource sharing
 * @author Cloud Computing Marketplace Team
 */
contract Project {
    // Struct to represent a compute resource provider
    struct Provider {
        address providerAddress;
        string ipAddress;
        uint256 cpuCores;
        uint256 ramGB;
        uint256 storageGB;
        uint256 pricePerHour; // Price in wei per hour
        bool isActive;
        uint256 reputation; // Reputation score out of 100
        uint256 totalJobsCompleted;
        uint256 totalEarnings;
    }
    
    // Struct to represent a compute job
    struct ComputeJob {
        uint256 jobId;
        address client;
        address assignedProvider;
        string jobDescription;
        uint256 requiredCpuCores;
        uint256 requiredRamGB;
        uint256 requiredStorageGB;
        uint256 estimatedDurationHours;
        uint256 totalPayment;
        uint256 startTime;
        JobStatus status;
        bool paymentReleased;
    }
    
    // Enum for job status
    enum JobStatus {
        Posted,
        Assigned,
        InProgress,
        Completed,
        Disputed,
        Cancelled
    }
    
    // State variables
    mapping(address => Provider) public providers;
    mapping(uint256 => ComputeJob) public jobs;
    mapping(address => uint256[]) public providerJobs;
    mapping(address => uint256[]) public clientJobs;
    
    address[] public activeProviders;
    uint256 public nextJobId;
    uint256 public platformFeePercentage = 5; // 5% platform fee
    address public owner;
    
    // Events
    event ProviderRegistered(address indexed provider, uint256 cpuCores, uint256 ramGB, uint256 pricePerHour);
    event JobPosted(uint256 indexed jobId, address indexed client, uint256 totalPayment);
    event JobAssigned(uint256 indexed jobId, address indexed provider);
    event JobCompleted(uint256 indexed jobId, address indexed provider, uint256 payment);
    event PaymentReleased(uint256 indexed jobId, address indexed provider, uint256 amount);
    event ReputationUpdated(address indexed provider, uint256 newReputation);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyActiveProvider() {
        require(providers[msg.sender].isActive, "Provider is not active");
        _;
    }
    
    modifier validJob(uint256 _jobId) {
        require(_jobId < nextJobId, "Invalid job ID");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        nextJobId = 1;
    }
    
    /**
     * @dev Core Function 1: Register as a compute resource provider
     * @param _ipAddress IP address of the provider's server
     * @param _cpuCores Number of CPU cores available
     * @param _ramGB Amount of RAM in GB
     * @param _storageGB Amount of storage in GB
     * @param _pricePerHour Price per hour in wei
     */
    function registerProvider(
        string memory _ipAddress,
        uint256 _cpuCores,
        uint256 _ramGB,
        uint256 _storageGB,
        uint256 _pricePerHour
    ) external {
        require(_cpuCores > 0, "CPU cores must be greater than 0");
        require(_ramGB > 0, "RAM must be greater than 0");
        require(_storageGB > 0, "Storage must be greater than 0");
        require(_pricePerHour > 0, "Price per hour must be greater than 0");
        require(!providers[msg.sender].isActive, "Provider already registered");
        
        providers[msg.sender] = Provider({
            providerAddress: msg.sender,
            ipAddress: _ipAddress,
            cpuCores: _cpuCores,
            ramGB: _ramGB,
            storageGB: _storageGB,
            pricePerHour: _pricePerHour,
            isActive: true,
            reputation: 50, // Starting reputation score
            totalJobsCompleted: 0,
            totalEarnings: 0
        });
        
        activeProviders.push(msg.sender);
        
        emit ProviderRegistered(msg.sender, _cpuCores, _ramGB, _pricePerHour);
    }
    
    /**
     * @dev Core Function 2: Post a compute job request
     * @param _jobDescription Description of the compute job
     * @param _requiredCpuCores Required CPU cores
     * @param _requiredRamGB Required RAM in GB
     * @param _requiredStorageGB Required storage in GB
     * @param _estimatedDurationHours Estimated duration in hours
     */
    function postJob(
        string memory _jobDescription,
        uint256 _requiredCpuCores,
        uint256 _requiredRamGB,
        uint256 _requiredStorageGB,
        uint256 _estimatedDurationHours
    ) external payable {
        require(_requiredCpuCores > 0, "Required CPU cores must be greater than 0");
        require(_requiredRamGB > 0, "Required RAM must be greater than 0");
        require(_estimatedDurationHours > 0, "Duration must be greater than 0");
        require(msg.value > 0, "Payment must be provided");
        
        uint256 jobId = nextJobId;
        nextJobId++;
        
        jobs[jobId] = ComputeJob({
            jobId: jobId,
            client: msg.sender,
            assignedProvider: address(0),
            jobDescription: _jobDescription,
            requiredCpuCores: _requiredCpuCores,
            requiredRamGB: _requiredRamGB,
            requiredStorageGB: _requiredStorageGB,
            estimatedDurationHours: _estimatedDurationHours,
            totalPayment: msg.value,
            startTime: 0,
            status: JobStatus.Posted,
            paymentReleased: false
        });
        
        clientJobs[msg.sender].push(jobId);
        
        emit JobPosted(jobId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Complete a job and release payment
     * @param _jobId ID of the job to complete
     * @param _reputationScore Reputation score for the provider (1-100)
     */
    function completeJobAndPay(uint256 _jobId, uint256 _reputationScore) external validJob(_jobId) {
        ComputeJob storage job = jobs[_jobId];
        
        require(msg.sender == job.client, "Only job client can complete the job");
        require(job.status == JobStatus.InProgress, "Job must be in progress");
        require(!job.paymentReleased, "Payment already released");
        require(_reputationScore >= 1 && _reputationScore <= 100, "Invalid reputation score");
        
        // Calculate platform fee and provider payment
        uint256 platformFee = (job.totalPayment * platformFeePercentage) / 100;
        uint256 providerPayment = job.totalPayment - platformFee;
        
        // Update job status
        job.status = JobStatus.Completed;
        job.paymentReleased = true;
        
        // Update provider stats
        Provider storage provider = providers[job.assignedProvider];
        provider.totalJobsCompleted++;
        provider.totalEarnings += providerPayment;
        
        // Update reputation (weighted average)
        uint256 totalJobs = provider.totalJobsCompleted;
        provider.reputation = ((provider.reputation * (totalJobs - 1)) + _reputationScore) / totalJobs;
        
        // Transfer payments
        payable(job.assignedProvider).transfer(providerPayment);
        payable(owner).transfer(platformFee);
        
        emit JobCompleted(_jobId, job.assignedProvider, providerPayment);
        emit PaymentReleased(_jobId, job.assignedProvider, providerPayment);
        emit ReputationUpdated(job.assignedProvider, provider.reputation);
    }
    
    /**
     * @dev Assign a job to a provider (simplified auto-assignment)
     * @param _jobId ID of the job to assign
     * @param _providerAddress Address of the provider to assign
     */
    function assignJob(uint256 _jobId, address _providerAddress) external validJob(_jobId) {
        ComputeJob storage job = jobs[_jobId];
        Provider storage provider = providers[_providerAddress];
        
        require(msg.sender == job.client, "Only job client can assign the job");
        require(job.status == JobStatus.Posted, "Job must be in posted status");
        require(provider.isActive, "Provider must be active");
        require(provider.cpuCores >= job.requiredCpuCores, "Insufficient CPU cores");
        require(provider.ramGB >= job.requiredRamGB, "Insufficient RAM");
        require(provider.storageGB >= job.requiredStorageGB, "Insufficient storage");
        
        job.assignedProvider = _providerAddress;
        job.status = JobStatus.Assigned;
        job.startTime = block.timestamp;
        
        providerJobs[_providerAddress].push(_jobId);
        
        emit JobAssigned(_jobId, _providerAddress);
    }
    
    /**
     * @dev Start job execution (called by assigned provider)
     * @param _jobId ID of the job to start
     */
    function startJob(uint256 _jobId) external validJob(_jobId) onlyActiveProvider {
        ComputeJob storage job = jobs[_jobId];
        
        require(msg.sender == job.assignedProvider, "Only assigned provider can start the job");
        require(job.status == JobStatus.Assigned, "Job must be assigned");
        
        job.status = JobStatus.InProgress;
        job.startTime = block.timestamp;
    }
    
    /**
     * @dev Get provider details
     * @param _providerAddress Address of the provider
     */
    function getProvider(address _providerAddress) external view returns (Provider memory) {
        return providers[_providerAddress];
    }
    
    /**
     * @dev Get job details
     * @param _jobId ID of the job
     */
    function getJob(uint256 _jobId) external view validJob(_jobId) returns (ComputeJob memory) {
        return jobs[_jobId];
    }
    
    /**
     * @dev Get all active providers
     */
    function getActiveProviders() external view returns (address[] memory) {
        return activeProviders;
    }
    
    /**
     * @dev Get jobs for a specific client
     * @param _client Address of the client
     */
    function getClientJobs(address _client) external view returns (uint256[] memory) {
        return clientJobs[_client];
    }
    
    /**
     * @dev Get jobs for a specific provider
     * @param _provider Address of the provider
     */
    function getProviderJobs(address _provider) external view returns (uint256[] memory) {
        return providerJobs[_provider];
    }
    
    /**
     * @dev Update platform fee (only owner)
     * @param _newFeePercentage New fee percentage
     */
    function updatePlatformFee(uint256 _newFeePercentage) external onlyOwner {
        require(_newFeePercentage <= 10, "Platform fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }
    
    /**
     * @dev Deactivate a provider (only owner)
     * @param _providerAddress Address of the provider to deactivate
     */
    function deactivateProvider(address _providerAddress) external onlyOwner {
        providers[_providerAddress].isActive = false;
    }
}
