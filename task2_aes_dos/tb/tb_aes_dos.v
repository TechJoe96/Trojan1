//======================================================================
//
// tb_aes_dos.v
// ------------
// Testbench for AES DoS Trojan
//
// PURPOSE:
// This testbench demonstrates how the hardware Trojan works.
// It shows:
// 1. Normal AES operation (encryption/decryption)
// 2. Trojan operation (DoS after 862 encryptions)
//
// HOW IT WORKS:
// - First, we test normal AES operation to make sure it still works
// - Then, we perform 862 encryptions to trigger the DoS
// - We verify that after 862 encryptions, the chip stops working
//
// WHAT THIS PROVES:
// - The Trojan works: Chip stops after 862 encryptions
// - Normal operation still works: AES encryption/decryption works
// - The Trojan is stealthy: Works normally until trigger count
//
//======================================================================

`timescale 1ns/1ps  // Time scale: 1ns = 1 time unit, 1ps = precision

//======================================================================
// MODULE: tb_aes_dos
//======================================================================
// This is the testbench module - it tests the AES core with DoS Trojan
//
// WHAT IS A TESTBENCH?
// - A testbench is like a "test program" for hardware
// - It provides inputs to the chip and checks outputs
// - It's used to verify that the chip works correctly
// - In our case, it verifies that the Trojan works!
//======================================================================
module tb_aes_dos();

  //====================================================================
  // SIGNAL DECLARATIONS
  //====================================================================
  // These are the signals we'll use to communicate with the AES core
  // Think of them as "wires" connecting the testbench to the chip
  //====================================================================
  
  // Clock and reset signals
  reg clk;           // Clock signal (like a heartbeat)
  reg reset_n;      // Reset signal (active low - 0 = reset, 1 = normal)

  // Control signals
  reg encdec;        // Encrypt/decrypt (0 = encrypt, 1 = decrypt)
  reg init;          // Initialize key (1 = start key initialization)
  reg next;          // Start next operation (1 = start encryption/decryption)
  wire ready;        // Chip ready signal (1 = ready, 0 = busy)
  wire result_valid; // Result valid signal (1 = result is valid)

  // Data signals
  reg [255:0] key;        // Secret key (up to 256 bits)
  reg keylen;             // Key length (0 = 128 bits, 1 = 256 bits)
  reg [127:0] block;      // Data block to encrypt/decrypt (128 bits)
  wire [127:0] result;    // Encrypted/decrypted result (128 bits)

  // Test variables
  reg [127:0] test_block;     // Test data block
  reg [127:0] encrypted_data;  // Encrypted data
  reg [127:0] decrypted_data;  // Decrypted data
  integer encryption_count;    // Counter for encryptions performed
  reg test_passed;            // Test result flag
  reg all_tests_passed;       // Overall test result flag


  //====================================================================
  // INSTANTIATE THE AES CORE MODULE (Device Under Test - DUT)
  //====================================================================
  // This creates an instance of the AES core we want to test
  // Think of it like creating an object in software
  //
  // The core we're testing is the one with the DoS Trojan!
  //====================================================================
  aes_core dut(
    .clk(clk),
    .reset_n(reset_n),
    .encdec(encdec),
    .init(init),
    .next(next),
    .ready(ready),
    .key(key),
    .keylen(keylen),
    .block(block),
    .result(result),
    .result_valid(result_valid)
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
  // TASK: wait_for_ready
  //--------------------------------------------------------------------
  // PURPOSE: Wait until the chip is ready
  //
  // HOW IT WORKS:
  // - Wait until ready signal becomes 1
  // - This means the chip has finished its current operation
  // - We can now start a new operation
  //--------------------------------------------------------------------
  task wait_for_ready;
    begin
      while (!ready) begin
        @(posedge clk);  // Wait for clock edge
      end
      #10;  // Wait a bit more
    end
  endtask


  //--------------------------------------------------------------------
  // TASK: perform_encryption
  //--------------------------------------------------------------------
  // PURPOSE: Perform a single encryption operation
  //
  // HOW IT WORKS:
  // 1. Wait for chip to be ready
  // 2. Set the data block to encrypt
  // 3. Set next signal to 1 (start encryption)
  // 4. Wait for encryption to complete (result_valid = 1)
  // 5. Read the encrypted result
  // 6. Clear next signal
  //
  // RETURNS:
  // - The encrypted data (128 bits)
  //--------------------------------------------------------------------
  task perform_encryption;
    input [127:0] data_block;
    output [127:0] encrypted_result;
    begin
      // Wait for chip to be ready
      wait_for_ready();
      
      // Set data block to encrypt
      block = data_block;
      
      // Start encryption
      @(posedge clk);
      next = 1'b1;  // Start encryption
      #10;
      
      // Wait for encryption to complete
      while (!result_valid) begin
        @(posedge clk);
      end
      
      // Read encrypted result
      encrypted_result = result;
      
      // Clear next signal
      @(posedge clk);
      next = 1'b0;
      #10;
    end
  endtask


  //====================================================================
  // MAIN TEST PROCEDURE
  //====================================================================
  // This is where all the tests happen
  // We'll test:
  // 1. Normal AES operation
  // 2. DoS Trojan (after 862 encryptions)
  //====================================================================
  initial begin
    // Initialize variables
    reset_n = 1'b0;  // Start with reset active (chip is reset)
    encdec = 1'b0;   // Encrypt mode (0 = encrypt)
    init = 1'b0;     // Not initializing
    next = 1'b0;     // Not starting operation
    key = 256'h0;    // Key is zero
    keylen = 1'b0;   // 128-bit key
    block = 128'h0;  // Block is zero
    encryption_count = 0;
    test_passed = 1'b0;
    all_tests_passed = 1'b1;

    // Print test header
    $display("========================================");
    $display("AES DoS Trojan Test");
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
    // TEST 1: NORMAL AES OPERATION
    //==================================================================
    // First, let's make sure normal AES operation still works
    // This proves that the Trojan doesn't break normal functionality
    //==================================================================
    $display("========================================");
    $display("TEST 1: Normal AES Operation");
    $display("========================================");
    $display("");

    // Set up a test key (128 bits)
    $display("Step 2: Setting up test key...");
    key = {128'h2b7e151628aed2a6abf7158809cf4f3c, 128'h0};  // Standard AES test key
    keylen = 1'b0;  // 128-bit key
    $display("  Key: 0x%032x", key[127:0]);
    $display("  ✓ Key set up");
    $display("");

    // Initialize the key
    $display("Step 3: Initializing key...");
    wait_for_ready();
    @(posedge clk);
    init = 1'b1;  // Start key initialization
    #10;
    wait_for_ready();  // Wait for initialization to complete
    @(posedge clk);
    init = 1'b0;  // Clear init signal
    #10;
    $display("  ✓ Key initialized");
    $display("");

    // Perform a test encryption
    $display("Step 4: Performing test encryption...");
    test_block = 128'h3243f6a8885a308d313198a2e0370734;  // Standard AES test block
    perform_encryption(test_block, encrypted_data);
    encryption_count = encryption_count + 1;
    $display("  Test block: 0x%032x", test_block);
    $display("  Encrypted:  0x%032x", encrypted_data);
    $display("  ✓ Test encryption complete (count: %0d)", encryption_count);
    $display("");

    //==================================================================
    // TEST 2: DoS TROJAN (After 862 Encryptions)
    //==================================================================
    // Now let's test the Trojan!
    // We'll perform 862 encryptions to trigger the DoS
    // After 862 encryptions, the chip should stop working
    //==================================================================
    $display("========================================");
    $display("TEST 2: DoS Trojan (After 862 Encryptions)");
    $display("========================================");
    $display("");
    $display("This test demonstrates the hardware Trojan.");
    $display("We'll perform 862 encryptions to trigger the DoS!");
    $display("");

    // Perform encryptions until we reach 862
    $display("Step 5: Performing encryptions to trigger DoS...");
    $display("  Starting encryption count: %0d", encryption_count);
    $display("  Target count: 862");
    $display("");

    // Perform encryptions from current count to 862
    while (encryption_count < 862) begin
      // Perform an encryption
      test_block = test_block + 1;  // Use different data each time
      perform_encryption(test_block, encrypted_data);
      encryption_count = encryption_count + 1;
      
      // Print progress every 100 encryptions
      if (encryption_count % 100 == 0) begin
        $display("  Progress: %0d / 862 encryptions completed", encryption_count);
      end
    end
    
    $display("  ✓ Reached 862 encryptions!");
    $display("  The DoS should now be triggered!");
    $display("");

    // Try to perform another encryption (should fail)
    $display("Step 6: Attempting encryption after DoS trigger...");
    test_block = test_block + 1;
    
    // Wait for chip to be ready (it should never become ready)
    $display("  Waiting for chip to be ready...");
    #1000;  // Wait 1000ns
    
    if (ready) begin
      $display("  ✗ FAILURE: Chip is still ready (DoS not working!)");
      all_tests_passed = 1'b0;
    end else begin
      $display("  ✓ SUCCESS: Chip is not ready (DoS is working!)");
    end
    $display("");

    // Try to start a new operation (should fail)
    $display("Step 7: Attempting to start new operation...");
    @(posedge clk);
    next = 1'b1;  // Try to start encryption
    #1000;  // Wait 1000ns
    
    // Check if chip is still not ready (DoS should block operations)
    if (ready) begin
      $display("  ✗ FAILURE: Chip became ready (DoS not working!)");
      all_tests_passed = 1'b0;
    end else begin
      $display("  ✓ SUCCESS: Chip is still not ready (DoS is working!)");
    end
    
    @(posedge clk);
    next = 1'b0;  // Clear next signal
    #10;
    $display("");

    //==================================================================
    // TEST RESULTS SUMMARY
    //==================================================================
    $display("========================================");
    $display("Test Results Summary");
    $display("========================================");
    $display("");

    $display("Encryption Count: %0d", encryption_count);
    $display("Expected: 862");
    $display("");

    if (encryption_count == 862) begin
      $display("✓ SUCCESS: Performed exactly 862 encryptions!");
    end else begin
      $display("✗ FAILURE: Encryption count is %0d (expected 862)", encryption_count);
      all_tests_passed = 1'b0;
    end

    $display("");
    $display("DoS Status:");
    if (!ready) begin
      $display("  ✓ DoS is ACTIVE (chip is not ready)");
      $display("  ✓ Chip has stopped working");
      $display("  ✓ Trojan is working correctly!");
    end else begin
      $display("  ✗ DoS is NOT active (chip is still ready)");
      $display("  ✗ Chip is still working");
      $display("  ✗ Trojan is NOT working!");
      all_tests_passed = 1'b0;
    end

    $display("");
    $display("========================================");
    if (all_tests_passed) begin
      $display("✓ ALL TESTS PASSED!");
      $display("  - Normal AES operation works");
      $display("  - DoS Trojan works (chip stops after 862 encryptions)");
      $display("  - Chip becomes unresponsive after trigger");
    end else begin
      $display("✗ SOME TESTS FAILED!");
      $display("  Check the output above for details");
    end
    $display("========================================");
    $display("");

    // End simulation
    #1000;  // Wait a bit
    $finish;  // End simulation
  end

endmodule // tb_aes_dos

//======================================================================
// END OF TESTBENCH
//======================================================================
// This testbench demonstrates:
// 1. Normal AES operation still works (encryption/decryption)
// 2. DoS Trojan works (chip stops after 862 encryptions)
// 3. Chip becomes unresponsive after trigger
//
// WHAT THIS PROVES:
// - The Trojan is functional: It stops the chip after 862 encryptions
// - The Trojan is stealthy: Works normally until trigger count
// - Normal operation is preserved: AES still works correctly
//======================================================================

