// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IAdminApp } from "../core/AccessControl/IAdminApp.sol";
import { IReentrancyGuardApp } from "../core/AccessControl/IReentrancyGuardApp.sol";
import { LibDomain } from "../../libraries/LibDomain.sol";

interface ITokenERC20 {
    function deposit() external payable;
    function approve(address spender, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;
}

library LibDex {
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("dex.standard.storage");
    

    struct Gateway {
        string name;
        address onlyReceiveSwapTokenAddres;     
        address owner; 
        bool enabled;                  
    }


    struct AirdropRule {
        uint256 balanceToken;
        uint256 factor;
    }    

    struct Router {
        string name;
        address router;
        bool enabled;
    }

    struct Quote {
        string routerName;
        address routerAddress;
        address tokenInAddress;
        uint256 tokenInAmount;
        uint256 receiveTokenAmount;
        uint256 deadline;
        uint256 slippageRate; 
        uint112 maxAvailableAmount;
        uint112 maxAvailableAmountReceiveToken;
    }

    struct Order {
        bool preOrder;
        uint256 amount;
        uint256 price;
        bool isSellOrder;
        bool isActive;
        address owner;
        uint256 burnTokensClose;
        address salesTokenAddress;
    }

    struct DexStorage{
        mapping(bytes32 => Gateway) gateways;
        mapping(bytes32 => mapping(address => Order[])) buyOrders;
        mapping(bytes32 => mapping(address => Order[])) sellOrders;
        mapping(bytes32 => mapping(address => uint256)) totalCapUSD;
        mapping(bytes32 => mapping(address => uint256)) totalShellOfferTokens;
        mapping(bytes32 => mapping(address => uint256)) totalSoldTokens;
        mapping(bytes32 => mapping(address => uint256)) airdropAmount;
        mapping(bytes32 => mapping(address => mapping(address => uint256))) earnedTokens;
        mapping(bytes32 => mapping(address => mapping(address => uint256))) boughtTokens;
        mapping(bytes32 => mapping(address => uint256)) currentOrder;
        mapping(bytes32 => mapping(address => uint256)) tokensBurned;
        mapping(bytes32 => mapping(address => AirdropRule[])) airdropRules;
        mapping(bytes32 => mapping(address => address)) destination;     
        mapping(bytes32 => mapping(address => bool)) preOrder;   
        mapping(bytes32 => Router[]) liquidityRouters;
        mapping(bytes32 => mapping(address => uint256)) liquidityRoutersIndex;       
        address wrappedNativeTokenAddress;
        bool initialized;
    }

    function domainStorage() internal pure returns (DexStorage storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }     
}

contract DexApp  {
  
    event GatewayCreated(bytes32 gatewayId, string gatewayName);
    event OrderCreated(address indexed owner, address salesTokenAddress, uint256 amount, uint256 price, bool isSellOrder);
    event OrderCanceled(address indexed owner, uint256 orderIndex);
    event OrderExecuted(address indexed buyer, address indexed seller, uint256 amount, uint256 price);
    event TokensClaimed(address indexed claimer, uint256 amount);

    function _initDex() public {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        require(!ds.initialized, "Initialization has already been executed.");

        // Setting up roles for specific functions
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("_initDex()"))), LibDex.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("createGateway(string,address,LibDex.Router[])"))), LibDex.DEFAULT_ADMIN_ROLE);
        IAdminApp(address(this)).setFunctionRole(bytes4(keccak256(bytes("setTokenDestination(bytes32,address,address)"))), LibDex.DEFAULT_ADMIN_ROLE);
        // Protecting the contract's functions from reentrancy attacks
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("swapTokenWithRouter(bytes32,address,address,address,uint256,address,address)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("createPurchOrder(bytes32,address,bool,uint256,uint256,uint256)"))), true);
        IReentrancyGuardApp(address(this)).enableDisabledFunctionReentrancyGuard(bytes4(keccak256(bytes("cancelOrder(bytes32,address,uint256,bool)"))), true);


        ds.initialized = true;
        LibDomain.DomainStorage storage dsDomain = LibDomain.domainStorage();
        address feature = dsDomain.featureAddressAndSelectorPosition[bytes4(keccak256(bytes("_initDex()")))].featureAddress;
        IReentrancyGuardApp(address(this)).enableDisabledDomainReentrancyGuard(true);
    }

    function createGateway(string memory _gatewayName, address _onlyReceiveSwapTokenAddres, LibDex.Router[] memory _routers) public returns (bytes32) {
        bytes32 gatewayId = keccak256(abi.encodePacked(_gatewayName));
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];

        gateway.name = _gatewayName;
        gateway.onlyReceiveSwapTokenAddres = _onlyReceiveSwapTokenAddres;
        gateway.enabled = true;
        gateway.owner = msg.sender;
        ds.wrappedNativeTokenAddress = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270); //wmatc
        for (uint256 i = 0; i < _routers.length; i++) {
            ds.liquidityRouters[gatewayId].push(_routers[i]);
            ds.liquidityRoutersIndex[gatewayId][_routers[i].router] = ds.liquidityRouters[gatewayId].length - 1;
        }

        emit GatewayCreated(gatewayId, _gatewayName);
        return gatewayId;
    }

    function gatewayExists(bytes32 gatewayId) external view returns (bool) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];        
        return gateway.enabled; 
    }

    function isPreOrder(bytes32 gatewayId, address salesTokenAddress) external view returns (bool) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        return ds.preOrder[gatewayId][salesTokenAddress];
    }


    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    function addAirDropAmount(bytes32 gatewayId, address salesTokenAddress, uint256 amount) external returns (uint256) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        require(ds.gateways[gatewayId].owner == msg.sender, "Only the gateway owner can add the airdrop amount to the balance");
        ERC20(salesTokenAddress).transferFrom(msg.sender, address(this), amount);
        ds.airdropAmount[gatewayId][salesTokenAddress] += amount;
        return ds.airdropAmount[gatewayId][salesTokenAddress];
    }

    function removeAirDropAmount(bytes32 gatewayId, address salesTokenAddress, uint256 amount) external returns (uint256) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        require(ds.gateways[gatewayId].owner == msg.sender, "Only the gateway owner can remove the airdrop amount to the balance");
        ERC20(salesTokenAddress).transferFrom(address(this), msg.sender, amount);
        ds.airdropAmount[gatewayId][salesTokenAddress] -= amount;
        return ds.airdropAmount[gatewayId][salesTokenAddress];
    }    

    function getMaxAvailableAmount(bytes32 gatewayId, address router, address tokenIn) external view returns (uint112 r0, uint112 r1) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];
        address pairAddress = IUniswapV2Factory(IUniswapV2Router02(ds.liquidityRouters[gatewayId][ds.liquidityRoutersIndex[gatewayId][address(router)]].router).factory()).getPair(gateway.onlyReceiveSwapTokenAddres, tokenIn);
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        return (reserve0, reserve1);
    }

    function getSwapQuote(bytes32 gatewayId, address tokenIn, uint256 tokenInAmount) external view returns (LibDex.Quote[] memory) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];        
        LibDex.Quote[] memory quotesTemp = new LibDex.Quote[](ds.liquidityRouters[gatewayId].length);
        uint256 count = 0;
        for (uint i = 0; i < ds.liquidityRouters[gatewayId].length; i++) {
            if (ds.liquidityRouters[gatewayId][i].enabled) {
                address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = gateway.onlyReceiveSwapTokenAddres;

                uint112 maxAvailableAmount = 0;
                uint112 maxAvailableAmountReceiveToken = 0;
                try this.getMaxAvailableAmount(gatewayId, ds.liquidityRouters[gatewayId][i].router, tokenIn) returns (uint112 reserve0, uint112 reserve1){
                    maxAvailableAmount = reserve1;
                    maxAvailableAmountReceiveToken = reserve0;
                } catch {
                    maxAvailableAmount = 0; 
                    maxAvailableAmountReceiveToken = 0;
                }

                uint256[] memory amountsOut;
                uint256 receiveTokenAmount;
                uint256 slippageRate;
                try IUniswapV2Router02(ds.liquidityRouters[gatewayId][i].router).getAmountsOut(tokenInAmount, path) returns (uint256[] memory result) {
                    amountsOut = result;
                    receiveTokenAmount = amountsOut[1] * 10**(ERC20(tokenIn).decimals() - ERC20(gateway.onlyReceiveSwapTokenAddres).decimals());

                    if (amountsOut[1] > receiveTokenAmount && amountsOut[1] != 0) {
                        slippageRate = ((amountsOut[1] - receiveTokenAmount) * 10**(ERC20(tokenIn).decimals() - ERC20(gateway.onlyReceiveSwapTokenAddres).decimals())) / amountsOut[1];
                    } else {
                        slippageRate = 0;
                    }

                } catch {
                    continue; 
                }

                LibDex.Quote memory quote = LibDex.Quote({
                    routerName: ds.liquidityRouters[gatewayId][i].name,
                    routerAddress: ds.liquidityRouters[gatewayId][i].router,
                    tokenInAddress: tokenIn,
                    tokenInAmount: tokenInAmount,
                    deadline: block.timestamp + 15 seconds,
                    receiveTokenAmount: receiveTokenAmount,
                    slippageRate: slippageRate,
                    maxAvailableAmount: maxAvailableAmount,
                    maxAvailableAmountReceiveToken: maxAvailableAmountReceiveToken
                });
                quotesTemp[count] = quote;
                count++;
            }
        }

        LibDex.Quote[] memory validQuotes = new LibDex.Quote[](count);
        for (uint i = 0; i < count; i++) {
            validQuotes[i] = quotesTemp[i];
        }

        return validQuotes;
    }


    function swapNativeToken(bytes32 gatewayId, address salesTokenAddress, address airdropOriginAddress) external payable  {
        this.swapTokenWithRouter(gatewayId, salesTokenAddress, address(0), address(0), msg.value, msg.sender, airdropOriginAddress);
    }   

    function swapNativeTokenWithRouter(bytes32 gatewayId, address salesTokenAddress, address quoteRouter, address airdropOriginAddress) external payable  {
        this.swapTokenWithRouter(gatewayId, salesTokenAddress, address(0), quoteRouter, msg.value, msg.sender, airdropOriginAddress);
    }

    function swapToken(bytes32 gatewayId, address salesTokenAddress, address tokenIn, uint256 amountIn, address toAddress, address airdropOriginAddress) external {
        this.swapTokenWithRouter(gatewayId, salesTokenAddress, tokenIn, address(0), amountIn, toAddress, airdropOriginAddress);
    }

    function swapTokenWithRouter(bytes32 gatewayId, address salesTokenAddress, address tokenIn, address router, uint256 amountIn, address toAddress, address airdropOriginAddress) external {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];

        require(amountIn > 0, "Need to send native token value to swap");
        require(ds.sellOrders[gatewayId][salesTokenAddress].length > 0, "There are no token offers at the moment, please try again later.");

        address swapRouter;
        LibDex.Quote[] memory quotes;

        uint256 remainingValueInUSD = 0;
        if (tokenIn != gateway.onlyReceiveSwapTokenAddres) {
            quotes = this.getSwapQuote(gatewayId, tokenIn == address(0) ? ds.wrappedNativeTokenAddress : tokenIn, amountIn);
            require(quotes.length > 0, "Unable to get quote from liquidity pool");

            if (router == address(0)) {
                swapRouter = quotes[0].routerAddress;
            } else {
                swapRouter = ds.liquidityRouters[gatewayId][ds.liquidityRoutersIndex[gatewayId][router]].router;
            }

            require(swapRouter != address(0), "There is no liquidity needed in the selected pool.");

            if (tokenIn == address(0)) {
                tokenIn = ds.wrappedNativeTokenAddress;
                ITokenERC20(ds.wrappedNativeTokenAddress).deposit{value: amountIn}();
            }

            ERC20(tokenIn).transferFrom(toAddress, address(this), amountIn);
            ERC20(tokenIn).approve(swapRouter, amountIn);

            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = gateway.onlyReceiveSwapTokenAddres;

            remainingValueInUSD = IUniswapV2Router02(swapRouter).swapExactTokensForTokens(
                amountIn,
                0,
                path,
                address(this),
                block.timestamp + 5 minutes
                )[1];
        } else {
            ERC20(tokenIn).transferFrom(toAddress, address(this), amountIn);
            remainingValueInUSD = amountIn;
        }

        require(remainingValueInUSD > 0, "Balance in USD not enough for the exchange.");

        // Airdrop mechanism
        if(airdropOriginAddress != address(0)) {
            uint256 airdropAmount = 0;
            uint256 originBalance = ERC20(salesTokenAddress).balanceOf(airdropOriginAddress);
            for(uint i = 0; i < ds.airdropRules[gatewayId][salesTokenAddress].length; i++) {
                if(originBalance >= ds.airdropRules[gatewayId][salesTokenAddress][i].balanceToken) {
                    airdropAmount = (remainingValueInUSD / ds.airdropRules[gatewayId][salesTokenAddress][i].factor);
                    break;
                }
            }
            if(airdropAmount > 0 && ds.airdropAmount[gatewayId][salesTokenAddress] >= airdropAmount) {
                ERC20(salesTokenAddress).transfer(airdropOriginAddress, airdropAmount);
                ds.airdropAmount[gatewayId][salesTokenAddress] -= airdropAmount;
            }
        }

        // Trading mechanism
        while (remainingValueInUSD > 0 && ds.sellOrders[gatewayId][salesTokenAddress].length > 0) {
            LibDex.Order storage order = ds.sellOrders[gatewayId][salesTokenAddress][0];
            uint256 orderValueInUSD = (order.amount / 10**18) * (order.price / 10**12);
            if (orderValueInUSD <= remainingValueInUSD) {
                ds.totalCapUSD[gatewayId][salesTokenAddress] += orderValueInUSD;
                IERC20(order.salesTokenAddress).approve(toAddress, order.amount);
                IERC20(order.salesTokenAddress).transferFrom(address(this), toAddress, order.amount); 
                ds.totalSoldTokens[gatewayId][salesTokenAddress] += order.amount;
                ds.totalShellOfferTokens[gatewayId][salesTokenAddress] -= order.amount;
                remainingValueInUSD -= orderValueInUSD;

                if (order.burnTokensClose > 0) {
                    if (order.isSellOrder && order.preOrder && ds.currentOrder[gatewayId][salesTokenAddress] == ds.sellOrders[gatewayId][salesTokenAddress].length) {
                        order.burnTokensClose += ERC20(address(this)).balanceOf(address(this));
                        ds.airdropAmount[gatewayId][salesTokenAddress] = 0;
                        IAdminApp(salesTokenAddress).removeFunctionRole(bytes4(keccak256(bytes("transfer(address,uint256)"))));  
                        IAdminApp(salesTokenAddress).removeFunctionRole(bytes4(keccak256(bytes("transferFrom(address,address,uint256)")))); 
                        IAdminApp(salesTokenAddress).removeFunctionRole(bytes4(keccak256(bytes("approve(address,uint256)")))); 
                        IAdminApp(salesTokenAddress).removeFunctionRole(bytes4(keccak256(bytes("burn(uint256)")))); 
                        IAdminApp(salesTokenAddress).removeFunctionRole(bytes4(keccak256(bytes("burnFrom(address,uint256)"))));                         
                        IAdminApp(salesTokenAddress).removeFunctionRole(bytes4(keccak256(bytes("createPurchOrder(bytes32,address,bool,uint256,uint256,uint256)"))));                          
                    }
                    ITokenERC20(order.salesTokenAddress).burn(order.burnTokensClose); 
                    ds.tokensBurned[gatewayId][salesTokenAddress] += order.burnTokensClose;
                    order.burnTokensClose = 0;
                }
                ds.currentOrder[gatewayId][salesTokenAddress]++;

                for (uint i = 0; i < ds.sellOrders[gatewayId][salesTokenAddress].length - 1; i++) {
                    ds.sellOrders[gatewayId][salesTokenAddress][i] = ds.sellOrders[gatewayId][salesTokenAddress][i + 1];
                }
                ds.sellOrders[gatewayId][salesTokenAddress].pop();
            } else {
                if (remainingValueInUSD > 0) {
                    uint256 partialOrderAmount = (remainingValueInUSD / (order.price / 10**12)) * 10**18;
                    ds.totalCapUSD[gatewayId][salesTokenAddress] += remainingValueInUSD;
                    IERC20(order.salesTokenAddress).approve(toAddress, partialOrderAmount);
                    IERC20(order.salesTokenAddress).transferFrom(address(this), toAddress, partialOrderAmount);
                    ds.totalSoldTokens[gatewayId][salesTokenAddress] += partialOrderAmount;
                    ds.totalShellOfferTokens[gatewayId][salesTokenAddress] -= partialOrderAmount;
                    order.amount -= partialOrderAmount;
                }
                remainingValueInUSD = 0;
            }
        }

        if (remainingValueInUSD > 0) {
            IERC20(gateway.onlyReceiveSwapTokenAddres).transfer(toAddress, remainingValueInUSD);
        }
    }


    function getAirdropFactor(bytes32 gatewayId, address salesTokenAddress, uint256 balance) internal view returns (uint256) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        LibDex.AirdropRule[] memory rules = ds.airdropRules[gatewayId][salesTokenAddress];

        for (uint256 i = 0; i < rules.length; i++) {
            if (balance <= rules[i].balanceToken) {
                return rules[i].factor;
            }
        }
        return 1; 
    }

    function setTokenDestination(bytes32 gatewayId, address salesTokenAddress, address payable _destination) public {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        ds.destination[gatewayId][salesTokenAddress] = _destination;
    }

    function createPurchOrder(bytes32 gatewayId, address salesTokenAddress, bool preOrder, uint256 amount, uint256 price, uint256 tokenBurnedOnClose) public  {
        unchecked {
        LibDex.Order memory order = LibDex.Order({
            preOrder: preOrder,
            amount: amount,
            price: price,
            isSellOrder: true,
            isActive: true,
            owner: msg.sender,
            burnTokensClose: tokenBurnedOnClose,
            salesTokenAddress: salesTokenAddress
        });

        LibDex.DexStorage storage ds = LibDex.domainStorage();  
        require(!ds.preOrder[gatewayId][salesTokenAddress] || ds.gateways[gatewayId].owner == msg.sender, "Cannot create orders until all cycles pre-seed are completed");
        ERC20(salesTokenAddress).transferFrom(msg.sender, address(this), amount+tokenBurnedOnClose);

        if(preOrder && !ds.preOrder[gatewayId][salesTokenAddress]){
            ds.preOrder[gatewayId][salesTokenAddress] = true;
            IAdminApp(salesTokenAddress).setFunctionRole(bytes4(keccak256(bytes("transfer(address,uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);    
            IAdminApp(salesTokenAddress).setFunctionRole(bytes4(keccak256(bytes("transferFrom(address,address,uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);  
            IAdminApp(salesTokenAddress).setFunctionRole(bytes4(keccak256(bytes("approve(address,uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);  
            IAdminApp(salesTokenAddress).setFunctionRole(bytes4(keccak256(bytes("burn(uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);  
            IAdminApp(salesTokenAddress).setFunctionRole(bytes4(keccak256(bytes("burnFrom(address,uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);       
            IAdminApp(salesTokenAddress).setFunctionRole(bytes4(keccak256(bytes("createPurchOrder(bytes32,address,bool,uint256,uint256,uint256)"))), LibDex.DEFAULT_ADMIN_ROLE);  
        }

        bool inserted = false;
        LibDex.Order[] memory shellOrders = ds.sellOrders[gatewayId][salesTokenAddress];
        for (uint i = 0; i < shellOrders.length; i++) {
            if (ds.sellOrders[gatewayId][salesTokenAddress][i].price > price) {
                ds.sellOrders[gatewayId][salesTokenAddress].push();
                LibDex.Order[] memory _shellOrders = ds.sellOrders[gatewayId][salesTokenAddress];
                for (uint j = _shellOrders.length - 1; j > i; j--) {
                    ds.sellOrders[gatewayId][salesTokenAddress][j] = ds.sellOrders[gatewayId][salesTokenAddress][j - 1];
                }
                ds.sellOrders[gatewayId][salesTokenAddress][i] = order;
                inserted = true;
                break;
            }
        }

        if (!inserted) {
            ds.sellOrders[gatewayId][salesTokenAddress].push(order);
        }

        ds.totalShellOfferTokens[gatewayId][salesTokenAddress] += amount;

        emit OrderCreated(order.owner, salesTokenAddress, amount, price, true); 
                }
    }

    function cancelOrder(bytes32 gatewayId, address salesTokenAddress, uint256 orderIndex, bool isSellOrder) public {
        LibDex.DexStorage storage ds = LibDex.domainStorage();  
        LibDex.Order storage order = isSellOrder ? ds.sellOrders[gatewayId][salesTokenAddress][orderIndex] : ds.buyOrders[gatewayId][salesTokenAddress][orderIndex];
        require(order.owner == msg.sender, "Only the owner can cancel the order");

        // Refund tokens if it's a sell order
        if (order.isSellOrder) {
            ERC20(order.salesTokenAddress).transfer(msg.sender, order.amount+order.burnTokensClose);
        }

        // Remove the order from the list
        if (order.isSellOrder) {
            for (uint i = orderIndex; i < ds.sellOrders[gatewayId][salesTokenAddress].length - 1; i++) {
                ds.sellOrders[gatewayId][salesTokenAddress][i] = ds.sellOrders[gatewayId][salesTokenAddress][i + 1];
            }
            ds.sellOrders[gatewayId][salesTokenAddress].pop();
        } else {
            for (uint i = orderIndex; i < ds.buyOrders[gatewayId][salesTokenAddress].length - 1; i++) {
                ds.buyOrders[gatewayId][salesTokenAddress][i] = ds.buyOrders[gatewayId][salesTokenAddress][i + 1];
            }
            ds.buyOrders[gatewayId][salesTokenAddress].pop();
        }

        emit OrderCanceled(msg.sender, orderIndex);
    }

    function getSalesOrder(bytes32 gatewayId, address salesTokenAddress) public  view returns (LibDex.Order memory){
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        return ds.sellOrders[gatewayId][salesTokenAddress][0];
    }

    function getActiveBuyOrders(bytes32 gatewayId, address salesTokenAddress) public view returns (LibDex.Order[] memory) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        uint256 activeCount = 0;
        for (uint256 i = 0; i < ds.buyOrders[gatewayId][salesTokenAddress].length; i++) {
            if (ds.buyOrders[gatewayId][salesTokenAddress][i].isActive) {
                activeCount++;
            }
        }
        
        LibDex.Order[] memory activeOrders = new LibDex.Order[](activeCount);
        uint256 j = 0;
        for (uint256 i = 0; i < ds.buyOrders[gatewayId][salesTokenAddress].length; i++) {
            if(ds.buyOrders[gatewayId][salesTokenAddress][i].isActive) {
                activeOrders[j] = ds.buyOrders[gatewayId][salesTokenAddress][i];
                j++;
            }
        }
        return activeOrders;
    }

    function getActiveSellOrders(bytes32 gatewayId, address salesTokenAddress) public view returns (LibDex.Order[] memory) {
        LibDex.DexStorage storage ds = LibDex.domainStorage();
        uint256 activeCount = 0;
        for (uint256 i = 0; i < ds.sellOrders[gatewayId][salesTokenAddress].length; i++) {
            if (ds.sellOrders[gatewayId][salesTokenAddress][i].isActive) {
                activeCount++;
            }
        }
        
        LibDex.Order[] memory activeOrders = new LibDex.Order[](activeCount);
        uint256 j = 0;
        for (uint256 i = 0; i < ds.sellOrders[gatewayId][salesTokenAddress].length; i++) {
            if (ds.sellOrders[gatewayId][salesTokenAddress][i].isActive) {
                activeOrders[j] = ds.sellOrders[gatewayId][salesTokenAddress][i];
                j++;
            }
        }
        return activeOrders;
    }


}
