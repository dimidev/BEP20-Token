// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakeFactory.sol";

contract MyToken is ERC20, Ownable {
    using SafeMath for uint256;

    string private constant TOKEN_NAME = "MyToken";
    string private constant TOKEN_SYMBOL = "MT";
    uint256 private constant TOTAL_SUPPLY = 1_000_000_000 * 1e18;

    address private constant PANCAKE_ROUTER_ADDRESS =
        0xD99D1c33F9fC3444f8101754aBC46c52416550D1;

    IPancakeRouter02 private immutable _pancakeRouter;
    address public immutable pancakePair;

    uint256 private constant TAX_FEE = 5; // 5%

    uint256 private constant MAX_TX_AMOUNT = 20000 * 1e18; // 2%
    uint256 private constant MAX_WALLET = 20000 * 1e18; // 2%
    uint256 private _swapThreshold = 20000 * 1e18; // 2%

    mapping(address => bool) private _excludedFromFees;
    mapping(address => bool) private _excludedFromMaxTxAmount;
    mapping(address => bool) private _excludedFromMaxWallet;

    mapping(address => bool) private _automatedMarketMakerPairs;

    bool inSwapAndLiquify;
    bool private _swapAndLiquifyEnabled = true;

    event SetAutomatedMarketMakerPair(address indexed pair, bool value);
    event ExcludeFromFees(address indexed account, bool excluded);
    event ExcludeFromMaxTxAmount(address indexed account, bool excluded);
    event ExcludeFromMaxWallet(address indexed account, bool excluded);
    event UpdateSwapAndLiquidyEnabled(bool enabled);
    event UpdateSwapTreshold(uint256 prevTreshold, uint256 newTreshold);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event ClaimTokens(address indexed account, uint256 balance);

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() ERC20(TOKEN_NAME, TOKEN_SYMBOL) {
        _mint(msg.sender, TOTAL_SUPPLY);

        _pancakeRouter = IPancakeRouter02(PANCAKE_ROUTER_ADDRESS);

        pancakePair = IPancakeFactory(_pancakeRouter.factory()).createPair(
            address(this),
            _pancakeRouter.WETH()
        );

        _setAutomatedMarketMakerPair(address(pancakePair), true);

        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(
            address(0x0000000000000000000000000000000000000000),
            true
        );
        excludeFromFees(
            address(0x000000000000000000000000000000000000dEaD),
            true
        );

        excludeFromMaxTxAmount(owner(), true);
        excludeFromMaxTxAmount(address(this), true);
        excludeFromMaxTxAmount(
            address(0x0000000000000000000000000000000000000000),
            true
        );
        excludeFromMaxTxAmount(
            address(0x000000000000000000000000000000000000dEaD),
            true
        );
        excludeFromMaxTxAmount(address(_pancakeRouter), true);
        excludeFromMaxTxAmount(address(pancakePair), true);

        excludeFromMaxWallet(owner(), true);
        excludeFromMaxWallet(address(this), true);
        excludeFromMaxWallet(
            address(0x0000000000000000000000000000000000000000),
            true
        );
        excludeFromMaxWallet(
            address(0x000000000000000000000000000000000000dEaD),
            true
        );
        excludeFromMaxWallet(address(_pancakeRouter), true);

        emit Transfer(address(0), msg.sender, TOTAL_SUPPLY);
    }

    function taxReceiver() public view returns (address) {
        return owner();
    }

    function taxFee() public pure returns (uint256) {
        return TAX_FEE;
    }

    function maxTxAmount() public pure returns (uint256) {
        return MAX_TX_AMOUNT;
    }

    function maxWallet() public pure returns (uint256) {
        return MAX_WALLET;
    }

    function swapAndLiquifyEnabled() public view returns (bool) {
        return _swapAndLiquifyEnabled;
    }

    function swapTreshold() public view returns (uint256) {
        return _swapThreshold;
    }

    function feesBalance() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyOwner {
        require(
            pair != pancakePair,
            "The pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        _automatedMarketMakerPairs[pair] = value;

        excludeFromMaxTxAmount(pair, value);

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateSwapAndLiquifyEnabled(bool enabled) public onlyOwner {
        _swapAndLiquifyEnabled = enabled;

        emit UpdateSwapAndLiquidyEnabled(_swapAndLiquifyEnabled);
    }

    function updateSwapTreshold(uint256 newTreshold) public onlyOwner {
        require(
            newTreshold >= 0,
            "Treshold must be greater than or equal to 0"
        );

        require(
            newTreshold <= TOTAL_SUPPLY,
            "Treshold must be less than or equal to total supply"
        );

        uint256 prevTreshold = _swapThreshold;

        _swapThreshold = newTreshold;

        emit UpdateSwapTreshold(prevTreshold, newTreshold);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _excludedFromFees[account];
    }

    function excludeFromFees(address account, bool exclude) public onlyOwner {
        _excludedFromFees[account] = exclude;

        emit ExcludeFromFees(account, exclude);
    }

    function isExcludedFromMaxTxAmount(
        address account
    ) public view returns (bool) {
        return _excludedFromMaxTxAmount[account];
    }

    function excludeFromMaxTxAmount(
        address account,
        bool exclude
    ) public onlyOwner {
        _excludedFromMaxTxAmount[account] = exclude;

        emit ExcludeFromMaxTxAmount(account, exclude);
    }

    function isExcludedFromMaxWallet(
        address account
    ) public view returns (bool) {
        return _excludedFromMaxWallet[account];
    }

    function excludeFromMaxWallet(
        address account,
        bool exclude
    ) public onlyOwner {
        _excludedFromMaxWallet[account] = exclude;

        emit ExcludeFromMaxWallet(account, exclude);
    }

    function _calcFeeAmount(uint256 amount) private pure returns (uint256) {
        return amount.mul(TAX_FEE).div(100);
    }

    // swap for BNB all the collected fee and transfer them
    // to the taxReceiver address
    function swapTaxFees() public onlyOwner {
        uint256 _feesBalance = feesBalance();

        require(_feesBalance > 0, "Contract balance must be greater than zero");

        _swapAndLiquify(_feesBalance);
    }

    // withdraw all the collected fees to the taxReceiver address
    function withdrawTaxFees() public onlyOwner {
        uint256 _feesBalance = feesBalance();

        require(_feesBalance > 0, "Contract balance must be greater than zero");

        super._transfer(address(this), taxReceiver(), _feesBalance);
    }

    // claim all bnb tokens to the taxReceiver
    function claimTokens() public onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0, "Balance must be greater than zero");
        
        payable(taxReceiver()).transfer(balance);

        emit ClaimTokens(taxReceiver(), balance);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            balanceOf(from) >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        if (!inSwapAndLiquify && from != owner() && to != owner()) {
            // when buy
            if (
                _automatedMarketMakerPairs[from] &&
                !_excludedFromMaxTxAmount[to]
            ) {
                require(
                    amount <= MAX_TX_AMOUNT,
                    "Buy amount exceeds the maxTxAmount"
                );

                if (!_excludedFromMaxWallet[to]) {
                    require(
                        amount + balanceOf(to) <= MAX_WALLET,
                        "Max wallet exceeded"
                    );
                }
            }
            // when sell
            else if (
                !_excludedFromMaxTxAmount[from] &&
                _automatedMarketMakerPairs[to]
            ) {
                require(
                    amount <= MAX_TX_AMOUNT,
                    "Sell amount exceeds the maxTxAmount"
                );
            }
            // when transfer
            else {
                if (!_excludedFromMaxTxAmount[from]) {
                    require(
                        amount <= MAX_TX_AMOUNT,
                        "Sell amount exceeds the maxTxAmount"
                    );
                }

                if (!_excludedFromMaxWallet[to]) {
                    require(
                        amount + balanceOf(to) <= MAX_WALLET,
                        "Max wallet exceeded"
                    );
                }
            }
        }

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap ?
        uint256 contractFeesBalance = feesBalance();

        if(contractFeesBalance >= MAX_TX_AMOUNT){
            contractFeesBalance = MAX_TX_AMOUNT;
        }

        bool overMinTokenBalance = contractFeesBalance >= _swapThreshold;

        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            !_automatedMarketMakerPairs[from] &&
            _swapAndLiquifyEnabled
        ) {
            _swapAndLiquify(contractFeesBalance);
        }

        if (_excludedFromFees[from] || _excludedFromFees[to]) {
            super._transfer(from, to, amount);
        } else {
            uint256 fee = _calcFeeAmount(amount);
            uint256 total = amount.sub(fee);

            super._transfer(from, address(this), fee);
            super._transfer(from, to, total);
        }
    }

    function _swapAndLiquify(uint256 amount) private lockTheSwap {
        // capture the contract's current BNB balance
        uint256 initialBalance = address(this).balance;

        // swap tokens for BNB
        _swapTokensForBnb(amount);

        // how much BNB did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        emit SwapAndLiquify(amount, newBalance, 0);
    }

    function _swapTokensForBnb(uint256 amount) private {
        // generate the pancake pair path of token -> BNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _pancakeRouter.WETH();

        _approve(address(this), address(_pancakeRouter), amount);

        // make the swap to the taxReceiver wallet
        _pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of BNB
            path,
            taxReceiver(),
            block.timestamp
        );
    }

    // to recieve BNB from pancakeRouter when swaping
    receive() external payable {}
}
