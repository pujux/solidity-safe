//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Safe is Initializable {
    event ReceivedDeposit(address indexed sender, uint256 amount);
    event ProposedTransaction(address indexed proposer, uint256 indexed txId);
    event Approved(address indexed wallet, uint256 indexed txId);
    event Rejected(address indexed wallet, uint256 indexed txId);
    event Executed(address indexed wallet, uint256 indexed txId);
    event Cancelled(address indexed wallet, uint256 indexed txId);

    enum Reaction {
        NONE,
        APPROVED,
        REJECTED
    }

    enum TransactionState {
        PENDING,
        EXECUTED,
        CANCELLED
    }

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        TransactionState state;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredApprovals;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => Reaction)) public reactions;

    modifier onlyOwners() {
        require(isOwner[msg.sender], "NOT_ALLOWED");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "UNKNOWN_TX");
        _;
    }

    modifier isPending(uint256 _txId) {
        require(
            transactions[_txId].state == TransactionState.PENDING,
            "TX_FINALIZED"
        );
        _;
    }

    function initialize(address[] memory _owners, uint256 _required)
        external
        initializer
    {
        require(_owners.length > 0, "NEED_OWNERS");
        require(_required > 0 && _owners.length >= _required, "WRONG_REQUIRED");
        requiredApprovals = _required;
        for (uint256 i; i < _owners.length; i++) {
            require(_owners[i] != address(0), "NULL_OWNER");
            require(!isOwner[_owners[i]], "DUPLICATE_OWNER");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
    }

    receive() external payable {
        emit ReceivedDeposit(msg.sender, msg.value);
    }

    function _approvalCount(uint256 _txId)
        private
        view
        returns (uint256 count)
    {
        for (uint256 i; i < owners.length; i++) {
            count += reactions[_txId][owners[i]] == Reaction.APPROVED ? 1 : 0;
        }
    }

    function _reactionCount(uint256 _txId)
        private
        view
        returns (uint256 count)
    {
        for (uint256 i; i < owners.length; i++) {
            count += reactions[_txId][owners[i]] != Reaction.NONE ? 1 : 0;
        }
    }

    function proposeTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwners {
        require(address(this).balance >= _value, "INSUFFICIENT_BALANCE");
        transactions.push(
            Transaction(_to, _value, _data, TransactionState.PENDING)
        );
        emit ProposedTransaction(msg.sender, transactions.length - 1);
        approve(transactions.length - 1);
    }

    function approve(uint256 _txId)
        public
        onlyOwners
        txExists(_txId)
        isPending(_txId)
    {
        reactions[_txId][msg.sender] = Reaction.APPROVED;
        emit Approved(msg.sender, _txId);
    }

    function reject(uint256 _txId)
        public
        onlyOwners
        txExists(_txId)
        isPending(_txId)
    {
        reactions[_txId][msg.sender] = Reaction.REJECTED;
        emit Rejected(msg.sender, _txId);
    }

    function finalize(uint256 _txId)
        external
        onlyOwners
        txExists(_txId)
        isPending(_txId)
    {
        require(
            _approvalCount(_txId) >= requiredApprovals ||
                _reactionCount(_txId) == owners.length,
            "CANNOT_FINALIZE"
        );
        Transaction storage transaction = transactions[_txId];
        if (_approvalCount(_txId) >= requiredApprovals) {
            (bool sent, ) = transaction.to.call{value: transaction.value}(
                transaction.data
            );
            require(sent, "TX_FAILED");
            transaction.state = TransactionState.EXECUTED;
            emit Executed(msg.sender, _txId);
        } else {
            transaction.state = TransactionState.CANCELLED;
            emit Cancelled(msg.sender, _txId);
        }
    }
}
