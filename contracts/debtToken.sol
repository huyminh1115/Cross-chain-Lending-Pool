// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {WadRayMath} from "./libraries/math/WadRayMath.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract debtToken is ERC20Upgradeable {
    using WadRayMath for uint256;

    ILendingPool internal _pool;
    address internal _underlyingAsset;
    uint8 _decimals;

    modifier onlyLendingPool() {
        require(
            _msgSender() == address(_getLendingPool()),
            "CT_CALLER_MUST_BE_LENDING_POOL"
        );
        _;
    }

    function initialize(
        ILendingPool pool,
        address underlyingAsset,
        uint8 debtTokenDecimals,
        string memory debtTokenName,
        string memory debtTokenSymbol
    ) public initializer {
        __ERC20_init(debtTokenName, debtTokenSymbol);
        _decimals = debtTokenDecimals;

        _pool = pool;
        _underlyingAsset = underlyingAsset;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Being non transferrable, the debt token does not implement any of the
     * standard ERC20 functions for transfer and allowance.
     **/
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        recipient;
        amount;
        revert("TRANSFER_NOT_SUPPORTED");
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        owner;
        spender;
        revert("ALLOWANCE_NOT_SUPPORTED");
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        spender;
        amount;
        revert("APPROVAL_NOT_SUPPORTED");
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        sender;
        recipient;
        amount;
        revert("TRANSFER_NOT_SUPPORTED");
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        override
        returns (bool)
    {
        spender;
        addedValue;
        revert("ALLOWANCE_NOT_SUPPORTED");
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        override
        returns (bool)
    {
        spender;
        subtractedValue;
        revert("ALLOWANCE_NOT_SUPPORTED");
    }

    /**
     * @dev Calculates the accumulated debt balance of the user
     * @return The debt balance of the user
     **/
    function balanceOf(address user)
        public
        view
        virtual
        override
        returns (uint256)
    {
        uint256 scaledBalance = super.balanceOf(user);

        if (scaledBalance == 0) {
            return 0;
        }
        return
            scaledBalance.rayMul(
                _pool.getReserveNormalizedVariableDebt(_underlyingAsset)
            );
    }

    /**
     * @dev Mints debt token to the `onBehalfOf` address
     * -  Only callable by the LendingPool
     * @param user The address receiving the borrowed underlying, being the delegatee in case
     * of credit delegate, or same as `onBehalfOf` otherwise
     * @param onBehalfOf The address receiving the debt tokens
     * @param amount The amount of debt being minted
     * @param index The variable debt index of the reserve
     * @return `true` if the the previous balance of the user is 0
     **/
    function mint(
        address user,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external onlyLendingPool returns (bool) {
        uint256 previousBalance = super.balanceOf(user);
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, "CT_INVALID_MINT_AMOUNT");

        _mint(user, amountScaled);

        return previousBalance == 0;
    }

    function burn(
        address user,
        uint256 amount,
        uint256 index
    ) external onlyLendingPool {
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, "CT_INVALID_BURN_AMOUNT");

        _burn(user, amountScaled);
    }

    /**
     * @dev Returns the principal debt balance of the user from
     * @return The debt balance of the user since the last burn/mint action
     **/
    function scaledBalanceOf(address user) public view returns (uint256) {
        return super.balanceOf(user);
    }

    /**
     * @dev Returns the total supply of the variable debt token. Represents the total debt accrued by the users
     * @return The total supply
     **/
    function totalSupply() public view virtual override returns (uint256) {
        return
            super.totalSupply().rayMul(
                _pool.getReserveNormalizedVariableDebt(_underlyingAsset)
            );
    }

    /**
     * @dev Returns the scaled total supply of the variable debt token. Represents sum(debt/index)
     * @return the scaled total supply
     **/
    function scaledTotalSupply() public view returns (uint256) {
        return super.totalSupply();
    }

    /**
     * @dev Returns the principal balance of the user and principal total supply.
     * @param user The address of the user
     * @return The principal balance of the user
     * @return The principal total supply
     **/
    function getScaledUserBalanceAndSupply(address user)
        external
        view
        returns (uint256, uint256)
    {
        return (super.balanceOf(user), super.totalSupply());
    }

    /**
     * @dev Returns the address of the underlying asset of this tToken (E.g. WETH for tWETH)
     **/
    function UNDERLYING_ASSET_ADDRESS() public view returns (address) {
        return _underlyingAsset;
    }

    /**
     * @dev Returns the address of the lending pool where this tToken is used
     **/
    function POOL() public view returns (ILendingPool) {
        return _pool;
    }

    function _getUnderlyingAssetAddress() internal view returns (address) {
        return _underlyingAsset;
    }

    function _getLendingPool() internal view returns (ILendingPool) {
        return _pool;
    }
}
