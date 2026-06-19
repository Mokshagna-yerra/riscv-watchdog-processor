// ============================================================
// MODULE 1 : riscv_core
// ============================================================
// Models the instruction-fetch stage of a single-cycle RV32I
// processor.
//
// KEY SIGNAL BEHAVIOURS:
//   mem_valid : driven HIGH always after reset.
//               Represents "I want to fetch an instruction."
//
//   mem_ready : driven by testbench (models memory response).
//               When LOW, the fetch cannot complete.
//
//   PC ADVANCE RULE (all three must be true simultaneously):
//     stall     == 0   (no external freeze)
//     mem_valid == 1   (core is requesting)
//     mem_ready == 1   (memory acknowledged)
//
//   If any condition fails → PC holds its current value.
//
//   rst_n : ACTIVE-LOW.  The core receives the AND of both
//           the system reset and the watchdog reset output.
// ============================================================
module riscv_core (
    input  wire        clk,
    input  wire        rst_n,       // active-low reset (system & watchdog)

    // Memory handshake bus
    output reg         mem_valid,   // 1 = core requesting a fetch (always 1 post-reset)
    input  wire        mem_ready,   // 1 = memory acknowledged (driven by testbench)

    // Control inputs
    input  wire        stall,       // 1 = freeze PC this cycle
    input  wire        trap,        // 1 = fault detected (watchdog monitors this)

    // Observability
    output reg  [31:0] pc,          // current program counter
    output wire        pc_active    // 1 when PC actually advanced this clock
);
    // PC advances only when all three handshake conditions met
    wire can_advance = (~stall) & mem_valid & mem_ready;
    assign pc_active = can_advance;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc        <= 32'h0000_0000;  // reset vector
            mem_valid <= 1'b0;           // silent until out of reset
        end else begin
            mem_valid <= 1'b1;           // always requesting a fetch
            if (can_advance)
                pc <= pc + 32'd4;        // advance to next instruction word
            // else: hold PC (stall asserted OR handshake incomplete)
        end
    end
endmodule
