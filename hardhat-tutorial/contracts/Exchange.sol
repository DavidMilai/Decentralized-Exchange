// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {
    address public cryptoDevTokenAddress;

    constructor(address _CryptoDevtoken) ERC20("CryptoDev LP Token", "CDLP") {
        require(
            _CryptoDevtoken != address(0),
            "Token address passed is a null address"
        );
        cryptoDevTokenAddress = _CryptoDevtoken;
    }

    function getReserve() public view returns (uint) {
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
    }

    function addLiquidity(uint _amount) public payable returns (uint) {
        uint liquidity;
        uint ethBalance = address(this).balance;
        uint cryptoDevTokenReserve = getReserve();
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);

        if (cryptoDevTokenReserve == 0) {
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);
            liquidity = ethBalance;
        } else {
            uint ethReserve = ethBalance - msg.value;

            uint cryptoDevTokenAmount = (msg.value * cryptoDevTokenReserve) /
                (ethReserve);
            require(
                _amount >= cryptoDevTokenAmount,
                "Amount of tokens sent is less than the minimum tokens required"
            );
            cryptoDevToken.transferFrom(
                msg.sender,
                address(this),
                cryptoDevTokenAmount
            );

            liquidity = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidity);
        }
        return liquidity;
    }


function removeLiquidity(uint _amount) public returns (uint , uint) {
    require(_amount > 0, "_amount should be greater than zero");
    uint ethReserve = address(this).balance;
    uint _totalSupply = totalSupply();
    // to read
    // The amount of Eth that would be sent back to the user is based
    // on a ratio
    // Ratio is -> (Eth sent back to the user) / (current Eth reserve)
    // = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
    // Then by some maths -> (Eth sent back to the user)
    // = (current Eth reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
    uint ethAmount = (ethReserve * _amount)/ _totalSupply;
    // The amount of Crypto Dev token that would be sent back to the user is based
    // on a ratio
    // Ratio is -> (Crypto Dev sent back to the user) / (current Crypto Dev token reserve)
    // = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
    // Then by some maths -> (Crypto Dev sent back to the user)
    // = (current Crypto Dev token reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
    uint cryptoDevTokenAmount = (getReserve() * _amount)/ _totalSupply;
    // Burn the sent LP tokens from the user's wallet because they are already sent to
    // remove liquidity
    _burn(msg.sender, _amount);
    // Transfer `ethAmount` of Eth from the contract to the user's wallet
    payable(msg.sender).transfer(ethAmount);
    // Transfer `cryptoDevTokenAmount` of Crypto Dev tokens from the contract to the user's wallet
    ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevTokenAmount);
    return (ethAmount, cryptoDevTokenAmount);
}

function getAmountOfTokens(
    uint256 inputAmount,
    uint256 inputReserve,
    uint256 outputReserve
) public pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
    // We are charging a fee of `1%`
    // Input amount with fee = (input amount - (1*(input amount)/100)) = ((input amount)*99)/100
    uint256 inputAmountWithFee = inputAmount * 99;
    // Because we need to follow the concept of `XY = K` curve
    // We need to make sure (x + Δx) * (y - Δy) = x * y
    // So the final formula is Δy = (y * Δx) / (x + Δx)
    // Δy in our case is `tokens to be received`
    // Δx = ((input amount)*99)/100, x = inputReserve, y = outputReserve
    // So by putting the values in the formulae you can get the numerator and denominator
    uint256 numerator = inputAmountWithFee * outputReserve;
    uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
    return numerator / denominator;
}

function cryptoDevTokenToEth(uint _tokensSold, uint _minEth) public {
    uint256 tokenReserve = getReserve();
    // call the `getAmountOfTokens` to get the amount of Eth
    // that would be returned to the user after the swap
    uint256 ethBought = getAmountOfTokens(
        _tokensSold,
        tokenReserve,
        address(this).balance
    );
    require(ethBought >= _minEth, "insufficient output amount");
    ERC20(cryptoDevTokenAddress).transferFrom(
        msg.sender,
        address(this),
        _tokensSold
    );
    // send the `ethBought` to the user from the contract
     payable(msg.sender).transfer(ethBought);
}

function ethToCryptoDevToken(uint _minTokens) public payable {
    uint256 tokenReserve = getReserve(); 
    uint256 tokensBought = getAmountOfTokens(
        msg.value,
        address(this).balance - msg.value,
        tokenReserve
    );

    require(tokensBought >= _minTokens, "insufficient output amount");
     ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought);
}

 

}
