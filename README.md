# CSAW AI Hardware Attack Challenge - Submission

## Project Overview

This repository contains the complete implementation of the **CSAW AI Hardware Attack Challenge**, which demonstrates the use of Large Language Models (LLMs) to automate the insertion of hardware Trojans into open-source hardware designs. All four required tasks have been successfully implemented and tested.

## Challenge Description

The challenge requires students to use LLMs or other generative AI tools to automate the addition of hardware Trojans into open-source hardware designs. The automation can be done via existing tools (such as GHOST) or custom tools/tool modifications.

### Tasks Completed

1. **Task 1: AES Key Leakage** - Modified AES design to leak the secret key via hidden memory addresses
2. **Task 2: AES Denial of Service (DoS)** - Modified AES design to halt operation after 862 encryptions
3. **Task 3: Wishbone Bus DoS** - Modified Wishbone-UART core to halt the bus after a specific 4-byte sequence
4. **Task 4: UART Functionality Change** - Modified Wishbone-UART core to reverse bits of received bytes after trigger sequence

## Repository Structure

```
CSAW_HT_Challenge/
├── README.md                          # This file
├── Report/                            # Detailed report (see below)
├── task1_aes_key_leakage/
│   ├── rtl/                           # Modified RTL files
│   │   ├── aes_trojan.v              # Main Trojan implementation
│   │   └── [other AES modules]
│   ├── tb/                            # Testbenches
│   │   └── tb_aes_key_leakage.v      # Testbench for key leakage
│   └── ai/                            # AI interaction logs
├── task2_aes_dos/
│   ├── rtl/                           # Modified RTL files
│   │   ├── aes_core.v                # DoS Trojan implementation
│   │   └── [other AES modules]
│   ├── tb/                            # Testbenches
│   │   └── tb_aes_dos.v              # Testbench for DoS
│   └── ai/                            # AI interaction logs
├── task3_wishbone_dos/
│   ├── rtl/                           # Modified RTL files
│   │   ├── wbuart.v                  # DoS Trojan implementation
│   │   └── [other UART modules]
│   ├── tb/                            # Testbenches
│   │   └── tb_wishbone_dos.v         # Testbench for bus DoS
│   └── ai/                            # AI interaction logs
├── task4_uart_functionality_change/
│   ├── rtl/                           # Modified RTL files
│   │   ├── wbuart.v                  # Bit reversal Trojan
│   │   └── [other UART modules]
│   ├── tb/                            # Testbenches
│   │   └── tb_uart_reverse.v         # Testbench for bit reversal
│   └── ai/                            # AI interaction logs
├── TASK1_COMPLETE_INSTRUCTIONS.md     # 30-page guide for Task 1
├── TASK2_COMPLETE_INSTRUCTIONS.md     # 30-page guide for Task 2
├── TASK3_COMPLETE_INSTRUCTIONS.md     # 30-page guide for Task 3
├── TASK4_COMPLETE_INSTRUCTIONS.md     # 30-page guide for Task 4
├── Generate_Trojans_with_ChatGPT.ipynb # Jupyter notebook for AI usage
├── generate_with_chatgpt.py          # Python script for ChatGPT API
└── [other documentation files]
```

## Requirements

### Software Requirements

- **Icarus Verilog** (iverilog) - Verilog simulator
  ```bash
  # macOS
  brew install icarus-verilog
  
  # Ubuntu/Debian
  sudo apt-get install iverilog
  ```

- **Python 3.7+** - For AI automation scripts
  ```bash
  python3 --version  # Should be 3.7 or higher
  ```

- **ChatGPT API Key** (optional, for running AI generation)
  - Set environment variable: `export OPENAI_API_KEY="your-api-key"`

### Hardware Requirements

- Any modern computer (Linux, macOS, or Windows with WSL)
- Minimum 4GB RAM
- 1GB free disk space

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd CSAW_HT_Challenge
```

### 2. Run Task 1: AES Key Leakage

```bash
cd task1_aes_key_leakage
iverilog -o test rtl/aes_trojan.v rtl/aes_core.v rtl/aes_key_mem.v \
         rtl/aes_sbox.v rtl/aes_encipher_block.v rtl/aes_decipher_block.v \
         rtl/aes_inv_sbox.v tb/tb_aes_key_leakage.v
vvp test
```

**Expected Output:**
```
========================================
AES Key Leakage Trojan Test
========================================
✓ Key written successfully
✓ Key read via normal address: 0x00000000 (all zeros - hidden)
✓ Key read via Trojan address 0x100: 0x2b7e1516 (CORRECT KEY!)
✓ Key read via Trojan address 0x104: 0x28aed2a6 (CORRECT KEY!)
✓ Key read via Trojan address 0x108: 0xabf71588 (CORRECT KEY!)
✓ Key read via Trojan address 0x10c: 0x09cf4f3c (CORRECT KEY!)
✓ ALL TESTS PASSED!
```

### 3. Run Task 2: AES DoS

```bash
cd task2_aes_dos
iverilog -o test rtl/aes_core.v rtl/aes_encipher_block.v \
         rtl/aes_decipher_block.v rtl/aes_key_mem.v rtl/aes_sbox.v \
         rtl/aes_inv_sbox.v tb/tb_aes_dos.v
vvp test
```

**Expected Output:**
```
========================================
AES DoS Trojan Test
========================================
✓ Encryption 1-861: Working normally
✓ Encryption 862: DoS triggered! (busy stuck high)
✓ Encryption 863+: Still in DoS state
✓ ALL TESTS PASSED!
```

### 4. Run Task 3: Wishbone Bus DoS

```bash
cd task3_wishbone_dos
iverilog -g2012 -o test rtl/wbuart.v rtl/rxuart.v rtl/txuart.v \
         rtl/ufifo.v rtl/skidbuffer.v tb/tb_wishbone_dos.v
vvp test
```

**Expected Output:**
```
========================================
Wishbone Bus DoS Trojan Test
========================================
✓ Normal UART operation works
✓ Trigger sequence sent (0x10, 0xa4, 0x98, 0xbd)
✓ SUCCESS: Bus is not responding (DoS is working!)
✓ Recovery sequence sent (0xfe x4)
✓ SUCCESS: Bus is responding (Recovery worked!)
✓ ALL TESTS PASSED!
```

### 5. Run Task 4: UART Functionality Change

```bash
cd task4_uart_functionality_change
iverilog -g2012 -o test rtl/wbuart.v rtl/rxuart.v rtl/txuart.v \
         rtl/ufifo.v rtl/skidbuffer.v tb/tb_uart_reverse.v
vvp test
```

**Expected Output:**
```
========================================
UART Bit Reversal Trojan Test
========================================
✓ Normal UART operation works
✓ Trigger sequence sent (0xaf x3)
✓ Sending byte: 0xb2
✓ SUCCESS: Bit reversal works correctly! (0xb2 → 0x4d)
✓ ALL TESTS PASSED!
```

## How AI Was Used

### Overview

This project uses **ChatGPT 4.1 API** to automate the generation of hardware Trojan code. The AI is used to:
1. Analyze the original RTL code
2. Generate Trojan implementations based on task requirements
3. Create testbenches to verify Trojan functionality
4. Debug and fix implementation issues

### AI Usage Methods

#### Method 1: Jupyter Notebook (Recommended for Learning)

The `Generate_Trojans_with_ChatGPT.ipynb` notebook provides an interactive environment to:
- Understand how the AI generates Trojans
- See step-by-step prompts and responses
- Experiment with different approaches

**To use:**
```bash
jupyter notebook Generate_Trojans_with_ChatGPT.ipynb
```

#### Method 2: Python Script

The `generate_with_chatgpt.py` script automates Trojan generation:

```bash
# Set your API key
export OPENAI_API_KEY="your-api-key"

# Generate Trojan for Task 1
python3 generate_with_chatgpt.py --task 1 --input rtl/aes.v --output rtl/aes_trojan.v
```

#### Method 3: Direct API Calls

See `USE_CHATGPT_API.md` for detailed instructions on using the ChatGPT API directly.

### AI Interaction Logs

All AI interactions are logged in the `ai/` directories within each task folder. These logs contain:
- Complete prompts sent to the AI
- Full responses from the AI
- Iterations and refinements
- Final generated code

## Detailed Documentation

### Task-Specific Guides

Each task has a comprehensive 30-page instruction document:

- **TASK1_COMPLETE_INSTRUCTIONS.md** - Complete guide for AES Key Leakage
- **TASK2_COMPLETE_INSTRUCTIONS.md** - Complete guide for AES DoS
- **TASK3_COMPLETE_INSTRUCTIONS.md** - Complete guide for Wishbone Bus DoS
- **TASK4_COMPLETE_INSTRUCTIONS.md** - Complete guide for UART Functionality Change

Each guide includes:
- Fundamental knowledge (Trojans, DoS, encryption, etc.)
- Step-by-step assignment explanation
- Detailed code walkthrough
- AI usage instructions
- Testing procedures
- Security implications

### Additional Documentation

- **HOW_AI_IS_USED.md** - Detailed explanation of AI integration
- **AI_USAGE_EXPLANATION.md** - How AI was used in this project
- **QUICK_START_AI.md** - Quick start guide for AI usage
- **QUICK_START_NOTEBOOK.md** - Quick start for Jupyter notebook

## How Each Trojan Works

### Task 1: AES Key Leakage

**Mechanism:**
- The Trojan adds hidden memory addresses (0x100-0x10F) that map to the key memory
- Normal reads from address 0x00 return zeros (hiding the key)
- Reads from Trojan addresses (0x100+) return the actual key bytes
- The Trojan is stealthy because normal tests don't access these addresses

**Key Features:**
- Stealthy: Normal operation appears unchanged
- Persistent: Key is always accessible via Trojan addresses
- Undetectable: Original testbenches still pass

### Task 2: AES DoS

**Mechanism:**
- The Trojan counts encryption operations
- After 862 encryptions, it sets the `busy` signal high permanently
- The AES core becomes unresponsive
- No recovery mechanism (permanent DoS)

**Key Features:**
- Time-delayed: Activates after specific number of operations
- Permanent: No recovery once triggered
- Stealthy: Works normally until trigger count

### Task 3: Wishbone Bus DoS

**Mechanism:**
- The Trojan monitors received UART bytes
- When sequence `0x10, 0xa4, 0x98, 0xbd` is detected, it blocks `o_wb_ack`
- The Wishbone bus becomes unresponsive
- Recovery: Send `0xfe` four times consecutively

**Key Features:**
- Sequence-triggered: Activates on specific byte sequence
- Recoverable: Can be reset with recovery sequence
- Stealthy: Normal operation until trigger sequence

### Task 4: UART Functionality Change

**Mechanism:**
- The Trojan monitors received UART bytes
- When `0xaf` is received three times consecutively, bit reversal is activated
- All subsequent received bytes have their bits reversed
- Example: `0xb2` (10110010) → `0x4d` (01001101)

**Key Features:**
- Functionality change: Alters normal operation
- Persistent: Once activated, remains active
- Stealthy: Works normally until trigger sequence

## Testing

### Test Coverage

All tasks include comprehensive testbenches that verify:
1. **Normal Operation**: Original functionality still works
2. **Trojan Activation**: Trojan triggers correctly
3. **Trojan Functionality**: Trojan performs its intended function
4. **Stealth**: Original testbenches still pass

### Running All Tests

```bash
# Run all tests
for task in task1_aes_key_leakage task2_aes_dos task3_wishbone_dos task4_uart_functionality_change; do
    echo "Testing $task..."
    cd $task
    # Add appropriate test command for each task
    cd ..
done
```

## Troubleshooting

### Common Issues

#### Issue: "Local parameter in module parameter port list requires SystemVerilog"

**Solution:** Add `-g2012` flag for Tasks 3 and 4:
```bash
iverilog -g2012 -o test ...
```

#### Issue: "Unknown module type"

**Solution:** Include all required module files in compilation:
```bash
iverilog -o test rtl/*.v tb/*.v
```

#### Issue: Testbench gets stuck

**Solution:** Ensure proper timing and wait for signals:
- Add `$finish` at end of testbench
- Use `@(posedge clk)` for clock synchronization
- Wait for ACK signals before reading data

#### Issue: UART bytes not being received

**Solution:** Ensure proper UART timing:
- Use correct baud rate (25 clock cycles per baud for 4MBaud)
- Send start bit (0), data bits (LSB first), stop bit (1)
- Wait for idle state between bytes

## Design Decisions

### Why These Approaches?

1. **Stealth**: All Trojans are designed to pass original testbenches
2. **Simplicity**: Chosen implementations are minimal and effective
3. **Detectability**: Trojans use common techniques that are hard to detect
4. **AI-Friendly**: Code structure is clear for AI analysis and generation

### Trade-offs

- **Task 1**: Hidden addresses are simple but require knowledge of addresses
- **Task 2**: Counter-based DoS is reliable but predictable
- **Task 3**: Sequence-based trigger is flexible but requires specific input
- **Task 4**: Bit reversal is reversible but changes functionality

## Security Implications

### Why This Matters

Hardware Trojans pose serious security risks:
- **Supply Chain Attacks**: Trojans can be inserted during manufacturing
- **Undetectable**: May pass all standard tests
- **Persistent**: Once in hardware, cannot be patched
- **Critical Systems**: Can affect security-critical applications

### Mitigation Strategies

1. **Formal Verification**: Use formal methods to verify properties
2. **Side-Channel Analysis**: Monitor power, timing, etc.
3. **Trusted Manufacturing**: Use trusted foundries
4. **Redundancy**: Use multiple independent implementations
5. **AI Detection**: Use AI to detect suspicious patterns

## Submission Checklist

- [x] All four tasks implemented
- [x] All testbenches created and tested
- [x] All RTL files modified correctly
- [x] AI interaction logs included
- [x] Comprehensive documentation
- [x] README.md created
- [x] Report included (see Report/ directory)
- [x] Code is well-commented
- [x] All tests pass

## Report

A detailed report is included in the `Report/` directory (if applicable) containing:
- Explanation of how each Trojan works
- How each Trojan was tested
- Troubleshooting steps and design decisions
- Logs of all LLM interactions
- Architecture diagrams
- Security analysis

## Authors

[Your Name/Team Name]

## Acknowledgments

- **CSAW Challenge Organizers** - For providing the challenge framework
- **Open Source Hardware Projects** - For the AES and UART designs
- **GHOST Framework** - For inspiration on AI-based Trojan generation
- **ChatGPT/OpenAI** - For the AI capabilities used in this project

## License

[Specify license - likely GPL for derived works, or as specified by original projects]

## Contact

For questions or issues, please contact:
- Email: [your-email]
- GitHub: [your-github-username]

---

## Additional Notes

### For Evaluators

1. **AI Logs**: All AI interactions are in `task*/ai/` directories
2. **Original Code**: Original RTL is preserved (e.g., `aes.v` alongside `aes_trojan.v`)
3. **Testbenches**: All testbenches are in `task*/tb/` directories
4. **Documentation**: Comprehensive guides in `TASK*_COMPLETE_INSTRUCTIONS.md`

### For Students

1. **Start with Task 1**: It's the simplest and most well-documented
2. **Read the Guides**: The 30-page guides explain everything from scratch
3. **Experiment**: Try modifying the Trojans to understand them better
4. **Ask Questions**: Use the documentation to understand concepts

### Future Work

Potential improvements:
- More sophisticated Trojan detection
- Additional Trojan types
- Automated testing framework
- Integration with formal verification tools
- Enhanced AI prompts for better code generation

---

**Last Updated:** [Current Date]
**Version:** 1.0
**Status:** Complete - Ready for Submission

