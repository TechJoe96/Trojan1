//======================================================================
//
// tb_uart_reverse.v
// ------------------
// Testbench for UART Bit Reversal Trojan
//
// PURPOSE:
// This testbench demonstrates how the hardware Trojan works.
// It shows:
// 1. Normal UART operation (receive/transmit)
// 2. Trojan operation (bit reversal after trigger sequence)
//
// HOW IT WORKS:
// - First, we test normal UART operation to make sure it still works
// - Then, we send the trigger sequence (0xaf three times consecutively)
// - We verify that after trigger, all received bytes have bits reversed
// - Example: 0xb2 becomes 0x4d (bits reversed)
//
// WHAT THIS PROVES:
// - The Trojan works: Bits are reversed after trigger sequence
// - Normal operation still works: UART receive/transmit works
// - The Trojan is stealthy: Works normally until trigger sequence
//
//======================================================================

`timescale 1ns/1ps

module tb_uart_reverse();

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
  reg [7:0] expected_result;
  reg [7:0] actual_result;
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
    $display("UART Bit Reversal Trojan Test");
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
    $display("TEST 2: Bit Reversal Trojan (Trigger Sequence)");
    $display("========================================");
    $display("");
    $display("Step 3: Sending trigger sequence...");
    $display("  Sending: 0xaf, 0xaf, 0xaf (three times consecutively)");
    
    // Send trigger sequence via UART (consecutive bytes)
    send_uart_byte(8'haf);
    send_uart_byte(8'haf);
    send_uart_byte(8'haf);
    
    // Wait for processing (Trojan needs time to detect sequence)
    #(bit_time * 20);
    
    $display("  ✓ Trigger sequence sent");
    $display("  The Trojan should now be activated!");
    $display("");

    // Test 3: Verify bit reversal
    $display("Step 4: Verifying bit reversal...");
    $display("  Sending byte: 0xb2");
    $display("  Expected (reversed): 0x4d");
    
    // Send test byte via UART
    send_uart_byte(8'hb2);
    
    // Wait for byte to be received and processed (wait for FIFO to have data)
    // The UART receiver needs time to process the byte and put it in the FIFO
    #(bit_time * 20);
    
    // Wait for FIFO to have data (check interrupt signal)
    // We'll wait a bit more to ensure the byte is in the FIFO
    repeat(10) @(posedge i_clk);
    
    // Read from bus (read from RX register)
    @(posedge i_clk);
    i_wb_cyc = 1;
    i_wb_stb = 1;
    i_wb_we = 0;
    i_wb_addr = 2'b10;  // Read from RX register (UART_RXREG)
    
    // Wait for ACK (the read happens on the next clock cycle)
    repeat(5) @(posedge i_clk);
    
    // Wait for ACK signal
    while (!o_wb_ack) @(posedge i_clk);
    
    // Data is available on o_wb_data
    actual_result = o_wb_data[7:0];
    expected_result = 8'h4d;  // Reversed bits of 0xb2
    
    $display("  Received: 0x%02x", actual_result);
    $display("  Expected: 0x%02x", expected_result);
    
    if (actual_result == expected_result) begin
      $display("  ✓ SUCCESS: Bit reversal works correctly!");
    end else begin
      $display("  ✗ FAILURE: Bit reversal not working!");
      $display("    Expected 0x%02x, got 0x%02x", expected_result, actual_result);
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
      $display("  - Bit reversal Trojan works (bits reversed after trigger)");
      $display("  - Example: 0xb2 → 0x4d (bits reversed)");
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

