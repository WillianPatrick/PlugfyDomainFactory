// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ITokenERC20 {
    function deposit() external payable;
    function approve(address spender, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;
}

library LibDex {
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 constant DOMAIN_STORAGE_POSITION = keccak256("dex.standard.storage");
    event OrderCreated(address indexed owner, address salesTokenAddress, uint256 amount, uint256 price, bool isSellOrder);

    struct Gateway {
        string name;
        address onlyReceiveSwapTokenAddres;      
        Router[] liquidityRouters;
        bool enabled;          
        mapping(address => uint256) liquidityRoutersIndex;    
        mapping(address => Order[]) buyOrders;
        mapping(address => Order[]) sellOrders;
        mapping(address => uint256) totalCapUSD;
        mapping(address => uint256) totalShellOfferTokens;
        mapping(address => uint256) totalSoldTokens;
        mapping(address => uint256) airdropAmount;
        mapping(address => mapping(address => uint256)) earnedTokens;
        mapping(address => mapping(address => uint256)) boughtTokens;
        mapping(address => uint256) currentOrder;
        mapping(address => uint256) tokensBurned;
        mapping(address => address) airdropAddress;
        mapping(address => address) destination;     
        mapping(address => bool) preOrder;         
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

    struct DomainStorage{
        mapping(bytes32 => Gateway) gateways;
        address wrappedNativeTokenAddress;
    }

    function domainStorage() internal pure returns (DomainStorage storage ds) {
        bytes32 position = DOMAIN_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }    

   function _createPurchOrder(bytes32 gatewayId, address salesTokenAddress, bool preOrder, uint256 amount, uint256 price, address orderOwner, uint256 tokenBurnedOnClose) internal   {
        Order memory order = Order({
            preOrder: preOrder,
            amount: amount,
            price: price,
            isSellOrder: true,
            isActive: true,
            owner: orderOwner,
            burnTokensClose: tokenBurnedOnClose,
            salesTokenAddress: salesTokenAddress
        });

        // Insert sell order in the right position (LibDex.Ordered by price)
        bool inserted = false;
        Gateway storage gw = domainStorage().gateways[gatewayId];
        gw.preOrder[salesTokenAddress] = preOrder;
        for (uint i = 0; i < gw.sellOrders[salesTokenAddress].length; i++) {
            if (gw.sellOrders[salesTokenAddress][i].price > price) {
                gw.sellOrders[salesTokenAddress].push();
                for (uint j = gw.sellOrders[salesTokenAddress].length - 1; j > i; j--) {
                    gw.sellOrders[salesTokenAddress][j] = gw.sellOrders[salesTokenAddress][j - 1];
                }
                gw.sellOrders[salesTokenAddress][i] = order;
                inserted = true;
                break;
            }
        }

        if (!inserted) {
            gw.sellOrders[salesTokenAddress][gw.sellOrders[salesTokenAddress].length - 1] = order;
        }

        gw.totalShellOfferTokens[salesTokenAddress] += amount;
        emit OrderCreated(order.owner, salesTokenAddress, amount, price, true);
    }    
}

contract DexApp  {
  

    event OrderCanceled(address indexed owner, uint256 orderIndex);
    event OrderExecuted(address indexed buyer, address indexed seller, uint256 amount, uint256 price);
    event TokensClaimed(address indexed claimer, uint256 amount);

    function createGateway(string memory _gatewayName, address _onlyReceiveSwapTokenAddres, LibDex.Router[] memory _routers) public returns (bytes32) {
        bytes32 gatewayId = keccak256(abi.encodePacked(_gatewayName));
        LibDex.DomainStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];

        gateway.name = _gatewayName;
        gateway.onlyReceiveSwapTokenAddres = _onlyReceiveSwapTokenAddres;
        gateway.enabled = true;

        for (uint256 i = 0; i < _routers.length; i++) {
            gateway.liquidityRouters.push(_routers[i]);
            gateway.liquidityRoutersIndex[_routers[i].router] = gateway.liquidityRouters.length - 1;
        }

        return gatewayId;
    }

    function gatewayExists(bytes32 gatewayId) external view returns (bool) {
        LibDex.DomainStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];        
        return gateway.enabled; 
    }

    function isPreOrder(bytes32 gatewayId, address salesTokenAddress) external view returns (bool) {
        LibDex.DomainStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];
        return gateway.preOrder[salesTokenAddress];
    }


    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    function getMaxAvailableAmount(bytes32 gatewayId, address router, address tokenIn) external view returns (uint112 r0, uint112 r1) {
        LibDex.DomainStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];
        address pairAddress = IUniswapV2Factory(IUniswapV2Router02(gateway.liquidityRouters[gateway.liquidityRoutersIndex[address(router)]].router).factory()).getPair(gateway.onlyReceiveSwapTokenAddres, tokenIn);
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        return (reserve0, reserve1);
    }

    function getSwapQuote(bytes32 gatewayId, address tokenIn, uint256 tokenInAmount) external view returns (LibDex.Quote[] memory) {
        LibDex.DomainStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];        
        LibDex.Quote[] memory quotesTemp = new LibDex.Quote[](gateway.liquidityRouters.length);
        uint256 count = 0;
        for (uint i = 0; i < gateway.liquidityRouters.length; i++) {
            if (gateway.liquidityRouters[i].enabled) {
                address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = gateway.onlyReceiveSwapTokenAddres;

                uint112 maxAvailableAmount = 0;
                uint112 maxAvailableAmountReceiveToken = 0;
                try this.getMaxAvailableAmount(gatewayId, gateway.liquidityRouters[i].router, tokenIn) returns (uint112 reserve0, uint112 reserve1){
                    maxAvailableAmount = reserve1;
                    maxAvailableAmountReceiveToken = reserve0;
                } catch {
                    maxAvailableAmount = 0; 
                    maxAvailableAmountReceiveToken = 0;
                }

                uint256[] memory amountsOut;
                uint256 receiveTokenAmount;
                uint256 slippageRate;
                try IUniswapV2Router02(gateway.liquidityRouters[i].router).getAmountsOut(tokenInAmount, path) returns (uint256[] memory result) {
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
                    routerName: gateway.liquidityRouters[i].name,
                    routerAddress: gateway.liquidityRouters[i].router,
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


    function swapNativeToken(bytes32 gatewayId, address salesTokenAddress) external payable  {
        this.swapToken(gatewayId, salesTokenAddress, address(0), address(0), msg.value, msg.sender);
    }   

    function swapNativeToken(bytes32 gatewayId, address salesTokenAddress, address quoteRouter) external payable  {
        this.swapToken(gatewayId, salesTokenAddress, address(0), quoteRouter, msg.value, msg.sender);
    }

    function swapToken(bytes32 gatewayId, address salesTokenAddress, address tokenIn, uint256 amountIn, address toAddress) external{
        this.swapToken(gatewayId, salesTokenAddress, tokenIn, address(0), amountIn, toAddress);
    }

  function swapToken(bytes32 gatewayId, address salesTokenAddress, address tokenIn, address router, uint256 amountIn, address toAddress) external payable {
    LibDex.DomainStorage storage ds = LibDex.domainStorage();
    LibDex.Gateway storage gateway = ds.gateways[gatewayId];

    require(amountIn > 0, "Need to send native token value to swap");
    require(gateway.sellOrders[salesTokenAddress].length > 0, "There are no token offers at the moment, please try again later.");

    address swapRouter;
    LibDex.Quote[] memory quotes;

    uint256 remainingValueInUSD = 0;
    if (tokenIn != gateway.onlyReceiveSwapTokenAddres) {
        quotes = this.getSwapQuote(gatewayId, tokenIn == address(0) ? ds.wrappedNativeTokenAddress : tokenIn, amountIn);
        require(quotes.length > 0, "Unable to get quote from liquidity pool");

        if (router == address(0)) {
            swapRouter = quotes[0].routerAddress;
        } else {
            swapRouter = gateway.liquidityRouters[gateway.liquidityRoutersIndex[router]].router;
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

    while (remainingValueInUSD > 0 && gateway.sellOrders[salesTokenAddress].length > 0) {
        LibDex.Order storage order = gateway.sellOrders[salesTokenAddress][0];
        uint256 orderValueInUSD = (order.amount / 10**18) * (order.price / 10**12);
        if (orderValueInUSD <= remainingValueInUSD) {
            gateway.totalCapUSD[salesTokenAddress] += orderValueInUSD;
            ERC20(order.salesTokenAddress).transfer(toAddress, order.amount); 
            gateway.totalSoldTokens[salesTokenAddress] += order.amount;
            gateway.totalShellOfferTokens[salesTokenAddress] -= order.amount;
            remainingValueInUSD -= orderValueInUSD;

            if (order.burnTokensClose > 0) {
                if (order.isSellOrder && order.preOrder && gateway.currentOrder[salesTokenAddress] == 5) {
                    order.burnTokensClose += ERC20(address(this)).balanceOf(address(this));
                }
                ITokenERC20(order.salesTokenAddress).burn(order.burnTokensClose); 
                gateway.tokensBurned[salesTokenAddress] += order.burnTokensClose;
                order.burnTokensClose = 0;
            }
            gateway.currentOrder[salesTokenAddress]++;

            for (uint i = 0; i < gateway.sellOrders[salesTokenAddress].length - 1; i++) {
                gateway.sellOrders[salesTokenAddress][i] = gateway.sellOrders[salesTokenAddress][i + 1];
            }
            gateway.sellOrders[salesTokenAddress].pop();
        } else {
            if (remainingValueInUSD > 0) {
                uint256 partialOrderAmount = (remainingValueInUSD / (order.price / 10**12)) * 10**18;
                gateway.totalCapUSD[salesTokenAddress] += remainingValueInUSD;
                ERC20(order.salesTokenAddress).transfer(toAddress, partialOrderAmount);
                gateway.totalSoldTokens[salesTokenAddress] += partialOrderAmount;
                gateway.totalShellOfferTokens[salesTokenAddress] -= partialOrderAmount;
                order.amount -= partialOrderAmount;
            }
            remainingValueInUSD = 0;
        }
    }

    if (remainingValueInUSD > 0) {
        ERC20(gateway.onlyReceiveSwapTokenAddres).transfer(toAddress, remainingValueInUSD);
    }
    }


    function setTokenDestination(bytes32 gatewayId, address salesTokenAddress, address payable _destination) public {
        LibDex.DomainStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];           
        gateway.destination[salesTokenAddress] = _destination;
    }

    function createPurchOrder(bytes32 gatewayId, address salesTokenAddress, uint256 amount, uint256 price) public  {
        LibDex.DomainStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];        
        require(gateway.sellOrders[salesTokenAddress].length == 0 || gateway.sellOrders[salesTokenAddress][0].preOrder == false, "Cannot create orders until all cycles pre-seed are completed");
        ERC20(salesTokenAddress).transferFrom(msg.sender, address(this), amount);
        LibDex._createPurchOrder(gatewayId, salesTokenAddress, false, amount, price, msg.sender, 0);
    }

    function cancelOrder(bytes32 gatewayId, address salesTokenAddress, uint256 orderIndex, bool isSellOrder) public {
        LibDex.DomainStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];          
        LibDex.Order storage order = isSellOrder ? gateway.sellOrders[salesTokenAddress][orderIndex] : gateway.buyOrders[salesTokenAddress][orderIndex];
        require(order.owner == msg.sender, "Only the owner can cancel the order");

        // Refund tokens if it's a sell order
        if (order.isSellOrder) {
            ERC20(order.salesTokenAddress).transfer(msg.sender, order.amount);
        }

        // Remove the order from the list
        if (order.isSellOrder) {
            for (uint i = orderIndex; i < gateway.sellOrders[salesTokenAddress].length - 1; i++) {
                gateway.sellOrders[salesTokenAddress][i] = gateway.sellOrders[salesTokenAddress][i + 1];
            }
            gateway.sellOrders[salesTokenAddress].pop();
        } else {
            for (uint i = orderIndex; i < gateway.buyOrders[salesTokenAddress].length - 1; i++) {
                gateway.buyOrders[salesTokenAddress][i] = gateway.buyOrders[salesTokenAddress][i + 1];
            }
            gateway.buyOrders[salesTokenAddress].pop();
        }

        emit OrderCanceled(msg.sender, orderIndex);
    }

    function getSalesOrder(bytes32 gatewayId, address salesTokenAddress) public  view returns (LibDex.Order memory){
        LibDex.DomainStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];            
        return gateway.sellOrders[salesTokenAddress][0];
    }

    function getActiveBuyOrders(bytes32 gatewayId, address salesTokenAddress) public view returns (LibDex.Order[] memory) {
        LibDex.DomainStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];            
        uint256 activeCount = 0;
        for (uint256 i = 0; i < gateway.buyOrders[salesTokenAddress].length; i++) {
            if (gateway.buyOrders[salesTokenAddress][i].isActive) {
                activeCount++;
            }
        }
        
        LibDex.Order[] memory activeOrders = new LibDex.Order[](activeCount);
        uint256 j = 0;
        for (uint256 i = 0; i < gateway.buyOrders[salesTokenAddress].length; i++) {
            if(gateway.buyOrders[salesTokenAddress][i].isActive) {
                activeOrders[j] = gateway.buyOrders[salesTokenAddress][i];
                j++;
            }
        }
        return activeOrders;
    }

    function getActiveSellOrders(bytes32 gatewayId, address salesTokenAddress) public view returns (LibDex.Order[] memory) {
        LibDex.DomainStorage storage ds = LibDex.domainStorage();
        LibDex.Gateway storage gateway = ds.gateways[gatewayId];            
        uint256 activeCount = 0;
        for (uint256 i = 0; i < gateway.sellOrders[salesTokenAddress].length; i++) {
            if (gateway.sellOrders[salesTokenAddress][i].isActive) {
                activeCount++;
            }
        }
        
        LibDex.Order[] memory activeOrders = new LibDex.Order[](activeCount);
        uint256 j = 0;
        for (uint256 i = 0; i < gateway.sellOrders[salesTokenAddress].length; i++) {
            if (gateway.sellOrders[salesTokenAddress][i].isActive) {
                activeOrders[j] = gateway.sellOrders[salesTokenAddress][i];
                j++;
            }
        }
        return activeOrders;
    }


}
