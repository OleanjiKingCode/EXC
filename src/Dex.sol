//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OleanjiGamesToken is ERC20 {
    address public egtAddress;
    ERC20 egtToken;

    constructor(address OGTAddress) ERC20("EXCLiquidityProvider", "ELP") {
        require(EGTAddress != address(0), "This is a zero address");
        egtAddress = EGTAddress;
        egtToken = ERC20(EGTAddress);
    }

    function AddLiquidity(uint EgtAmount) public payable returns (uint) {
        uint egtBalance = getTotalOfOGTReserve();
        uint lpGotten;
        uint maticBalance = address(this).balance;
        if (egtBalance == 0) {
            egtToken.transferFrom(msg.sender, address(this), EgtAmount);
            LpGotten = maticBalance;
            _mint(msg.sender, LpGotten);
        } else {
            uint maticCurrentBalance = maticBalance - msg.value;
            uint expectedEgtAmount = (msg.value * OgtBalance) /
                (maticCurrentBalance);
            require(
                EgtAmount >= expectedEgtAmount,
                "This is too small for the Matic you are putting"
            );
            egtToken.transferFrom(msg.sender, address(this), expectedEgtAmount);
            LpGotten = (totalSupply() * msg.value) / maticCurrentBalance;
            _mint(msg.sender, LpGotten);
        }
        return LpGotten;
    }

    function WithdrawLiquidity(uint amountToWithdawal)
        public
        returns (uint, uint)
    {
        require(
            amountToWithdawal > 0,
            "The amount is too small for a withdrawal"
        );
        uint maticBalance = getTotalOfOGTReserve();
        uint _totalSupply = totalSupply();
        uint maticEquivalent = (maticBalance * amountToWithdawal) /
            _totalSupply;
        uint EgtAmount = (totalSupply() * amountToWithdawal) / _totalSupply;
        _burn(msg.sender, amountToWithdawal);
        payable(msg.sender).transfer(maticEquivalent);
        ERC20(egtAddress).transfer(msg.sender, EgtAmount);
        return (maticEquivalent, EgtAmount);
    }

    function getAmountOfTokens(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        uint256 inputAmountWithFee = inputAmount * 99;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
        return numerator / denominator;
    }

    function SwapMaticToOgt(uint minTokens) public payable {
        uint OgtReserve = getTotalOfOGTReserve();

        uint tokenToCollect = getAmountOfTokens(
            msg.value,
            address(this).balance - msg.value,
            OgtReserve
        );
        require(tokenToCollect >= minTokens, "insufficient");
        ERC20(egtAddress).transfer(msg.sender, tokenToCollect);
    }

    function SwapOgtToMatic(uint Ogtsent, uint _mineth) public {
        uint OgtReserve = getTotalOfOGTReserve();

        uint tokenToCollect = getAmountOfTokens(
            Ogtsent,
            OgtReserve,
            address(this).balance
        );
        require(tokenToCollect >= _mineth, "insufficient");
        ERC20(egtAddress).transferFrom(
            msg.sender,
            address(this),
            tokenToCollect
        );
        payable(msg.sender).transfer(tokenToCollect);
    }

    function getTotalOfOGTReserve() public view returns (uint) {
        return ERC20(egtAddress).balanceOf(address(this));
    }
}
