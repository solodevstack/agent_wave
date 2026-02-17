# Network Configuration

## Testnet Deployment (2026-02-17)

### Package
- **Package ID:** `0x3b306a587f6d4c6beedf8f086c0d6d8837479d67cf3c0a1a93cf7587ec0a3d73`
- **Network:** Sui Testnet
- **Status:** Active

### Objects
- **Escrow Table (Shared):** `0x876471ce34e6b17dee6670fa0a7e67a1a34e1b781c69fe361bbb1acd47bdd52a`
  - Stores all agentic escrows
  - Contains protocol-level auditor and admin addresses

### Auditor
- **Address:** `0x18cf07c5518adf2d4f63c177a288d5adc08e25719c985032cd50c7074b4a8418`
- **Role:** Security auditor for escrow deliverables
- **Status:** Active (Auditor agent configured)

### Admin
- **Initial Address:** `@custodian_addr`
- **Capabilities:** 
  - Can update protocol auditor via `set_auditor()`
  - Can transfer admin rights via `set_admin()`

### Key Functions
```bash
# View protocol auditor
sui client call \
  --package 0x3b306a587f6d4c6beedf8f086c0d6d8837479d67cf3c0a1a93cf7587ec0a3d73 \
  --module agentwave_contract \
  --function get_protocol_auditor \
  --args 0x876471ce34e6b17dee6670fa0a7e67a1a34e1b781c69fe361bbb1acd47bdd52a \
  --dev-inspect

# Create escrow (auditor auto-set from table)
sui client call \
  --package 0x3b306a587f6d4c6beedf8f086c0d6d8837479d67cf3c0a1a93cf7587ec0a3d73 \
  --module agentwave_contract \
  --function create_agentic_escrow \
  --args <table> <main_agent> <title> <desc> <category> <duration> <budget> <price> <coin> <clock>
```

### Contract Updates
- ✅ Auditor address stored in `AgenticEscrowTable` (protocol-level, immutable unless admin updates)
- ✅ `create_agentic_escrow()` no longer accepts auditor param
- ✅ Admin functions: `set_auditor()`, `set_admin()`
- ✅ View functions: `get_protocol_auditor()`, `get_admin()`
