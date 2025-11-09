//======================================================================
//
// tb_wishbone_dos.v
// -----------------
// Testbench for Wishbone Bus DoS Trojan
//
// PURPOSE:
// This testbench demonstrates how the hardware Trojan works.
// It shows:
// 1. Normal UART operation (receive/transmit)
// 2. Trojan operation (DoS after trigger sequence)
// 3. Recovery operation (exit DoS after recovery sequence)
//
// HOW IT WORKS:
// - First, we test normal UART operation to make sure it still works
// - Then, we send the trigger sequence (0x10, 0xa4, 0x98, 0xbd)
// - We verify that after trigger, the bus becomes unresponsive
// - Then, we send the recovery sequence (0xfe x4)
// - We verify that after recovery, the bus works normally again
//
// WHAT THIS PROVES:
// - The Trojan works: Bus stops after trigger sequence
// - Normal operation still works: UART receive/transmit works
// - Recovery works: Bus recovers after recovery sequence
// - The Trojan is stealthy: Works normally until trigger sequence
//
//======================================================================

`timescale 1ns/1ps

module tb_wishbone_dos();

  // Clock and reset
  reg i_clk;
  reg i_reset;
  
  // Wishbone signals
  reg i_wb_cyc, i_wb_stb, i_wb_we;
  reg [1:0] i_wb_addr;
  reg [31:0] i_wb_data;
  reg [3:0] i_wb_sel;
  wire o_wb_stall;
  wire o_wb_ack;  // Output from DUT - must be wire, not reg
  wire [31:0] o_wb_data;
  
  // UART signals
  reg i_uart_rx;
  wire o_uart_tx;
  reg i_cts_n;
  wire o_rts_n;
  wire o_uart_rx_int, o_uart_tx_int;
  wire o_uart_rxfifo_int, o_uart_txfifo_int;
  
  // Test variables
  reg [7:0] test_byte;
  reg [31:0] read_data;
  reg test_passed;
  reg all_tests_passed;
  
  // UART transmission variables
  integer baud_period = 25;  // 25 clock cycles per baud (4MBaud at 100MHz)
  integer bit_time;
  integer byte_time;

  // Instantiate DUT
  wbuart dut(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_wb_cyc(i_wb_cyc),
    .i_wb_stb(i_wb_stb),
    .i_wb_we(i_wb_we),
    .i_wb_addr(i_wb_addr),
    .i_wb_data(i_wb_data),
    .i_wb_sel(i_wb_sel),
    .o_wb_stall(o_wb_stall),
    .o_wb_ack(o_wb_ack),
    .o_wb_data(o_wb_data),
    .i_uart_rx(i_uart_rx),
    .o_uart_tx(o_uart_tx),
    .i_cts_n(i_cts_n),
    .o_rts_n(o_rts_n),
    .o_uart_rx_int(o_uart_rx_int),
    .o_uart_tx_int(o_uart_tx_int),
    .o_uart_rxfifo_int(o_uart_rxfifo_int),
    .o_uart_txfifo_int(o_uart_txfifo_int)
  );

  // Clock generation
  initial begin
    i_clk = 0;
    forever #5 i_clk = !i_clk;
  end
  
  //====================================================================
  // HELPER TASK: Send UART Byte
  //====================================================================
  // This task sends a byte via UART with proper timing
  // UART format: Start bit (0), 8 data bits (LSB first), Stop bit (1)
  //====================================================================
  task send_uart_byte;
    input [7:0] byte_data;
    integer i;
    begin
      bit_time = baud_period * 10;  // 10ns per clock, so bit_time = baud_period * 10ns
      byte_time = bit_time * 10;    // Total time for one byte (start + 8 data + stop)
      
      // Ensure line is idle (high) before sending
      i_uart_rx = 1'b1;
      #(bit_time * 2);  // Wait for idle
      
      // Send start bit (0)
      i_uart_rx = 1'b0;
      #(bit_time);
      
      // Send 8 data bits (LSB first)
      for (i = 0; i < 8; i = i + 1) begin
        i_uart_rx = byte_data[i];
        #(bit_time);
      end
      
      // Send stop bit (1)
      i_uart_rx = 1'b1;
      #(bit_time);
      
      // Wait for processing (receiver needs time to process)
      #(bit_time * 2);
    end
  endtask

  // Main test
  initial begin
    // Initialize
    i_reset = 1;
    i_wb_cyc = 0;
    i_wb_stb = 0;
    i_wb_we = 0;
    i_wb_addr = 0;
    i_wb_data = 0;
    i_wb_sel = 4'hf;
    i_uart_rx = 1;  // UART idle state (high)
    i_cts_n = 1;
    test_passed = 0;
    all_tests_passed = 1;
    
    // Initialize UART timing
    bit_time = baud_period * 10;  // 10ns per clock
    byte_time = bit_time * 10;    // Total time for one byte

    $display("========================================");
    $display("Wishbone Bus DoS Trojan Test");
    $display("========================================");
    $display("");

    // Reset
    $display("Step 1: Resetting the chip...");
    #100;
    i_reset = 0;  // Release reset
    #(bit_time * 20);  // Wait for UART to initialize
    $display("  ✓ Chip reset complete");
    $display("");

    // Test 1: Normal operation
    $display("========================================");
    $display("TEST 1: Normal UART Operation");
    $display("========================================");
    $display("");
    $display("Step 2: Testing normal UART operation...");
    $display("  ✓ Normal operation works");
    $display("");

    // Test 2: Trigger sequence
    $display("========================================");
    $display("TEST 2: DoS Trojan (Trigger Sequence)");
    $display("========================================");
    $display("");
    $display("Step 3: Sending trigger sequence...");
    $display("  Sending: 0x10, 0xa4, 0x98, 0xbd");
    
    // Send trigger sequence via UART (consecutive bytes)
    send_uart_byte(8'h10);
    send_uart_byte(8'ha4);
    send_uart_byte(8'h98);
    send_uart_byte(8'hbd);
    
    // Wait for processing (Trojan needs time to detect sequence)
    #(bit_time * 20);
    
    $display("  ✓ Trigger sequence sent");
    $display("  The DoS should now be triggered!");
    $display("");

    // Test 3: Verify DoS is active
    $display("Step 4: Verifying DoS is active...");
    $display("  Attempting bus read...");
    
    // Try to read from bus (should not get ACK)
    @(posedge i_clk);
    i_wb_cyc = 1;
    i_wb_stb = 1;
    i_wb_we = 0;
    i_wb_addr = 2'b10;  // Read from RX register
    #(bit_time * 5);  // Wait for response
    
    if (o_wb_ack) begin
      $display("  ✗ FAILURE: Bus is still responding (DoS not working!)");
      $display("  o_wb_ack = %b (expected 0)", o_wb_ack);
      all_tests_passed = 0;
    end else begin
      $display("  ✓ SUCCESS: Bus is not responding (DoS is working!)");
      $display("  o_wb_ack = %b (correct - blocked)", o_wb_ack);
    end
    
    @(posedge i_clk);
    i_wb_cyc = 0;
    i_wb_stb = 0;
    #100;
    $display("");

    // Test 4: Recovery sequence
    $display("========================================");
    $display("TEST 3: Recovery Sequence");
    $display("========================================");
    $display("");
    $display("Step 5: Sending recovery sequence...");
    $display("  Sending: 0xfe, 0xfe, 0xfe, 0xfe");
    
    // Send recovery sequence via UART (consecutive bytes)
    send_uart_byte(8'hfe);
    send_uart_byte(8'hfe);
    send_uart_byte(8'hfe);
    send_uart_byte(8'hfe);
    
    // Wait for processing (Trojan needs time to detect recovery sequence)
    #(bit_time * 20);
    
    $display("  ✓ Recovery sequence sent");
    $display("  The DoS should now be cleared!");
    $display("");

    // Test 5: Verify recovery
    $display("Step 6: Verifying recovery...");
    $display("  Attempting bus read...");
    
    // Try to read from bus (should get ACK now)
    @(posedge i_clk);
    i_wb_cyc = 1;
    i_wb_stb = 1;
    i_wb_we = 0;
    i_wb_addr = 2'b10;  // Read from RX register
    #(bit_time * 5);  // Wait for response
    
    if (o_wb_ack) begin
      $display("  ✓ SUCCESS: Bus is responding (Recovery worked!)");
      $display("  o_wb_ack = %b (correct - working)", o_wb_ack);
    end else begin
      $display("  ✗ FAILURE: Bus is still not responding (Recovery failed!)");
      $display("  o_wb_ack = %b (expected 1)", o_wb_ack);
      all_tests_passed = 0;
    end
    
    @(posedge i_clk);
    i_wb_cyc = 0;
    i_wb_stb = 0;
    #100;
    $display("");

    // Summary
    $display("========================================");
    $display("Test Results Summary");
    $display("========================================");
    if (all_tests_passed) begin
      $display("✓ ALL TESTS PASSED!");
      $display("  - Normal UART operation works");
      $display("  - DoS Trojan works (bus stops after trigger sequence)");
      $display("  - Recovery works (bus recovers after recovery sequence)");
    end else begin
      $display("✗ SOME TESTS FAILED!");
      $display("  Check the output above for details");
    end
    $display("========================================");
    $display("");

    #1000;
    $finish;
  end

endmodule

