// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ERC20.sol";
import "./interfaces/HubI.sol";

contract GroupCurrencyToken is ERC20 {
    using SafeMath for uint256;

    uint8 public immutable override decimals = 18;
    uint8 public mintFeePerThousand;
    
    string public name;
    string public override symbol;

    address public owner; // the safe/EOA/contract that deployed this token, can be changed by owner
    address public hub; // the address of the hub this token is associated with
    address public treasury; // account which gets the personal tokens for whatever later usage

    mapping (address => bool) public directMembers;
    mapping (address => bool) public delegatedTrustees;
    
    event Minted(address indexed receiver, uint256 amount, uint256 mintAmount, uint256 mintFee);

    /// @dev modifier allowing function to be only called by the token owner
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // TODO: How is the owner set, who is deploying the contract? Should it be msg.sender or a parameter?
    constructor(address _hub, address _treasury, uint8 _mintFeePerThousand, string memory _name, string memory _symbol) {
        symbol = _symbol;
        name = _name;
        owner = msg.sender;
        hub = _hub;
        treasury = _treasury;
        mintFeePerThousand = _mintFeePerThousand;
    }
    
    function changeOwner(address _owner) public onlyOwner {
        owner = _owner;
    }
    
    function addMemberToken(address _member) public onlyOwner {
        directMembers[_member] = true;
    }

    function removeMemberToken(address _member) public onlyOwner {
        directMembers[_member] = false;
    }
    
    function addDelegatedTrustee(address _account) public onlyOwner {
        delegatedTrustees[_account] = true;
    }

    function removeDelegatedTrustee(address _account) public onlyOwner {
        delegatedTrustees[_account] = false;
    }
    
    // Group currently is created from collateral tokens. Collateral is directly part of the directMembers dictionary.
    function mint(address _collateral, uint256 _amount) public {
        require(directMembers[_collateral], "Collateral address is not marked as direct member.");
        transferCollateralAndMint(_collateral, _amount);
    }
    
    // Group currently is created from collateral tokens. Collateral is trusted by someone in the delegatedTrustees dictionary.
    function mintDelegate(address _trustedBy, address _collateral, uint256 _amount) public {
        require(_trustedBy != address(0), "trustedBy must be valid address.");
        // require(trusted_by in delegated_trustees)
        require(delegatedTrustees[_trustedBy], "trustedBy not contained in delegatedTrustees.");
        address collateralOwner = HubI(hub).tokenToUser(_collateral);
        // require(trusted_by.trust(collateral)
        require(HubI(hub).limits(_trustedBy, collateralOwner) > 0, "trustedBy does not trust collateral owner.");
        transferCollateralAndMint(_collateral, _amount);
    }
    
    function transferCollateralAndMint(address _collateral, uint256 _amount) internal {
        uint256 mintFee = (_amount.div(1000)).mul(mintFeePerThousand);
        ERC20(_collateral).transferFrom(msg.sender, treasury, _amount);
        uint256 mintAmount = _amount.sub(mintFee);
        // mint amount-fee to msg.sender
        _mint(msg.sender, mintAmount);
        emit Minted(msg.sender, _amount, mintAmount, mintFee);    
    }

    function transfer(address dst, uint256 wad) public override returns (bool) {
        // this code shouldn't be necessary, but when it's removed the gas estimation methods
        // in the gnosis safe no longer work, still true as of solidity 7.1
        return super.transfer(dst, wad);
    }
}