// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./TaqiNFT.sol";

/**
 * @title TaqiRoutes
 * @dev Contrato principal para la lógica de rutas, pagos y recompensas de TAQI.
 */
contract TaqiRoutes is Ownable, ReentrancyGuard {
    
    struct Route {
        uint256 id;
        string metadataURI; 
        uint256 usdcPrice;  
        bool isSpecialEvent;
        bool isActive;       
    }

    TaqiNFT public nftContract;
    IERC20 public usdcContract;
    address public oracle; 

    mapping(uint256 => Route) public routes;
    uint256 public nextRouteId;

    mapping(address => mapping(uint256 => bool)) public userCompletedRoutes;
    mapping(address => uint256) public userSeasonCompletions;

    event RouteCreated(uint256 indexed routeId, uint256 price, bool isSpecialEvent);
    event ChallengeStarted(address indexed user, uint256 indexed routeId);
    event ChallengeCompleted(address indexed user, uint256 indexed routeId);
    event NFTPurchased(address indexed user, uint256 indexed routeId);

    modifier onlyOracle() {
        require(msg.sender == oracle, "Only the oracle can call this function");
        _;
    }

    constructor(
        address initialOwner,
        address _nftAddress, 
        address _usdcAddress, 
        address _oracleAddress
    ) 
        Ownable(initialOwner)
        ReentrancyGuard()
    {
        nftContract = TaqiNFT(_nftAddress);
        usdcContract = IERC20(_usdcAddress);
        oracle = _oracleAddress;
        nextRouteId = 1;
    }

    function setOracle(address _newOracle) public onlyOwner {
        oracle = _newOracle;
    }

    function createRoute(string memory _metadataURI, uint256 _usdcPrice, bool _isSpecialEvent) public onlyOwner {
        routes[nextRouteId] = Route({
            id: nextRouteId,
            metadataURI: _metadataURI,
            usdcPrice: _usdcPrice,
            isSpecialEvent: _isSpecialEvent,
            isActive: true
        });
        emit RouteCreated(nextRouteId, _usdcPrice, _isSpecialEvent);
        nextRouteId++;
    }

    function startChallenge(uint256 _routeId) public nonReentrant {
        Route storage route = routes[_routeId];
        require(route.isActive, "Route is not active");
        require(!userCompletedRoutes[msg.sender][_routeId], "Route already completed");

        if (route.usdcPrice > 0) {
            bool success = usdcContract.transferFrom(msg.sender, address(this), route.usdcPrice);
            require(success, "USDC transfer failed");
            emit NFTPurchased(msg.sender, _routeId);
        }

        emit ChallengeStarted(msg.sender, _routeId);
    }
    
    function completeChallenge(address _user, uint256 _routeId) public onlyOracle {
        require(routes[_routeId].id != 0, "Route does not exist");
        require(!userCompletedRoutes[_user][_routeId], "Route already completed by user");

        userCompletedRoutes[_user][_routeId] = true;
        userSeasonCompletions[_user]++;
        
        nftContract.safeMint(_user);

        emit ChallengeCompleted(_user, _routeId);
    }

    // --- FUNCIÓN CORREGIDA ---
    function withdrawUSDC() public onlyOwner nonReentrant {
        uint256 balance = usdcContract.balanceOf(address(this));
        require(balance > 0, "No funds to withdraw");

        bool success = usdcContract.transfer(owner(), balance);
        require(success, "USDC transfer failed");
    }
}