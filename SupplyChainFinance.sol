// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SupplyChainFinance {
    enum Status {
        Registered,
        Verified,
        Funded,
        Repaid,
        Cancelled
    }

    struct TradeDocument {
        uint256 documentId;
        string documentHash;       // invoice hash / IPFS CID
        address exporter;
        address verifier;
        address lender;
        uint256 invoiceAmount;     // total invoice amount in wei for demo simplicity
        uint256 fundedAmount;      // amount funded by lender
        uint256 repaidAmount;      // amount repaid by exporter
        Status status;
        bool exists;
    }

    address public owner;
    uint256 public nextDocumentId;

    mapping(uint256 => TradeDocument) public documents;

    event DocumentRegistered(
        uint256 indexed documentId,
        address indexed exporter,
        string documentHash,
        uint256 invoiceAmount
    );

    event DocumentVerified(
        uint256 indexed documentId,
        address indexed verifier
    );

    event InvoiceFunded(
        uint256 indexed documentId,
        address indexed lender,
        uint256 fundedAmount
    );

    event InvoiceRepaid(
        uint256 indexed documentId,
        address indexed exporter,
        uint256 repaidAmount
    );

    event DocumentCancelled(
        uint256 indexed documentId,
        address indexed exporter
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier onlyExporter(uint256 _documentId) {
        require(documents[_documentId].exporter == msg.sender, "Only exporter can call this");
        _;
    }

    modifier documentExists(uint256 _documentId) {
        require(documents[_documentId].exists, "Document does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextDocumentId = 1;
    }

    function registerDocument(
        string memory _documentHash,
        uint256 _invoiceAmount
    ) external {
        require(bytes(_documentHash).length > 0, "Document hash required");
        require(_invoiceAmount > 0, "Invoice amount must be > 0");

        uint256 currentId = nextDocumentId;

        documents[currentId] = TradeDocument({
            documentId: currentId,
            documentHash: _documentHash,
            exporter: msg.sender,
            verifier: address(0),
            lender: address(0),
            invoiceAmount: _invoiceAmount,
            fundedAmount: 0,
            repaidAmount: 0,
            status: Status.Registered,
            exists: true
        });

        emit DocumentRegistered(currentId, msg.sender, _documentHash, _invoiceAmount);

        nextDocumentId++;
    }

    function verifyDocument(
        uint256 _documentId
    ) external onlyOwner documentExists(_documentId) {
        TradeDocument storage doc = documents[_documentId];

        require(doc.status == Status.Registered, "Document not in Registered status");

        doc.verifier = msg.sender;
        doc.status = Status.Verified;

        emit DocumentVerified(_documentId, msg.sender);
    }

    function fundInvoice(
        uint256 _documentId
    ) external payable documentExists(_documentId) {
        TradeDocument storage doc = documents[_documentId];

        require(doc.status == Status.Verified, "Document must be verified first");
        require(doc.lender == address(0), "Invoice already funded");
        require(msg.value > 0, "Funding must be > 0");
        require(msg.value <= doc.invoiceAmount, "Funding exceeds invoice amount");

        doc.lender = msg.sender;
        doc.fundedAmount = msg.value;
        doc.status = Status.Funded;

        payable(doc.exporter).transfer(msg.value);

        emit InvoiceFunded(_documentId, msg.sender, msg.value);
    }

    function repayInvoice(
        uint256 _documentId
    ) external payable documentExists(_documentId) onlyExporter(_documentId) {
        TradeDocument storage doc = documents[_documentId];

        require(doc.status == Status.Funded, "Invoice is not funded");
        require(doc.lender != address(0), "No lender recorded");
        require(msg.value == doc.fundedAmount, "Repayment must equal funded amount");

        doc.repaidAmount = msg.value;
        doc.status = Status.Repaid;

        payable(doc.lender).transfer(msg.value);

        emit InvoiceRepaid(_documentId, msg.sender, msg.value);
    }

    function cancelDocument(
        uint256 _documentId
    ) external documentExists(_documentId) onlyExporter(_documentId) {
        TradeDocument storage doc = documents[_documentId];

        require(doc.status == Status.Registered, "Only unverified docs can be cancelled");

        doc.status = Status.Cancelled;

        emit DocumentCancelled(_documentId, msg.sender);
    }

    function getDocument(
        uint256 _documentId
    )
        external
        view
        documentExists(_documentId)
        returns (
            uint256 documentId,
            string memory documentHash,
            address exporter,
            address verifier,
            address lender,
            uint256 invoiceAmount,
            uint256 fundedAmount,
            uint256 repaidAmount,
            Status status
        )
    {
        TradeDocument memory doc = documents[_documentId];

        return (
            doc.documentId,
            doc.documentHash,
            doc.exporter,
            doc.verifier,
            doc.lender,
            doc.invoiceAmount,
            doc.fundedAmount,
            doc.repaidAmount,
            doc.status
        );
    }
}