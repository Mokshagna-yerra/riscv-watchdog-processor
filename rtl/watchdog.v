// ============================================================
// MODULE 2 : watchdog
// ============================================================
// Monitors four fault conditions and generates a one-shot
// active-low reset pulse when any fault persists.
//
// FAULT DETECTION TABLE:
// ┌──────┬─────────────┬────────────────────────────────────┐
// │ Prio │ Fault       │ Detection Condition                 │
// ├──────┼─────────────┼────────────────────────────────────┤
// │  P1  │ TRAP        │ trap==1          → IMMEDIATE reset  │
// │  P2  │ MEM FAILURE │ valid & ~ready   → timeout reset    │
// │  P3  │ STALL       │ stall==1         → timeout reset    │
// │  P4  │ PC FREEZE   │ pc unchanged for │ FREEZE_IGNORE    │
// │      │             │ TIMEOUT cycles   │ startup grace    │
// └──────┴─────────────┴────────────────────────────────────┘
//
// ONE-SHOT MECHANISM:
//   fault_latched is SET when reset fires.
//   Only cleared by external sys_rst_n = 0.
//   Prevents repeated resets on the same fault event.
//
// RESET PULSE:
//   wdt_rst_n held LOW for exactly RESET_CYCLES clock edges.
//   After pulse: wdt_rst_n returns HIGH (system resumes).
//
// PC FREEZE GRACE PERIOD:
//   ignore_cnt suppresses pc_freeze detection for the first
//   FREEZE_IGNORE cycles after reset to avoid false triggers
//   during startup (before last_pc is valid).
// ============================================================
module watchdog #(
    parameter TIMEOUT       = 20,  // cycles of fault before timeout reset
    parameter RESET_CYCLES  =  8,  // width of wdt_rst_n LOW pulse (cycles)
    parameter FREEZE_IGNORE =  6   // startup grace period for PC freeze check
)(
    input  wire        clk,
    input  wire        rst_n,       // system reset (active-low); clears latch

    // Signals from riscv_core (observed every cycle)
    input  wire [31:0] pc,
    input  wire        mem_valid,
    input  wire        mem_ready,
    input  wire        stall,
    input  wire        trap,

    // Outputs
    output reg         wdt_rst_n,   // active-low reset to core (1=OK 0=RESET)
    output reg  [3:0]  fault_code   // fault bitmap at moment of firing
);
    // counter widths
    localparam CNT_W  = $clog2(TIMEOUT + 1);
    localparam IGN_W  = $clog2(FREEZE_IGNORE + 2);

    // internal registers
    reg [CNT_W-1:0] timeout_cnt;   // fault persistence counter
    reg [31:0]      last_pc;       // PC snapshot from previous cycle
    reg             fault_latched; // one-shot flag
    reg [3:0]       rst_hold;      // reset pulse down-counter
    reg [IGN_W-1:0] ignore_cnt;    // startup freeze-ignore counter

    // ── combinational fault detection ───────────────────────
    wire f_trap  = trap;
    wire f_mem   = mem_valid & (~mem_ready);
    wire f_stall = stall;
    // PC freeze only armed after grace period expires
    wire freeze_armed = (ignore_cnt >= FREEZE_IGNORE);
    wire f_pc    = freeze_armed & (pc == last_pc);
    wire any_timed = f_mem | f_stall | f_pc;

    // build fault_code at moment of firing (all active faults OR'd)
    wire [3:0] cur_fault = {f_trap, f_mem, f_stall, f_pc};

    // ── sequential watchdog FSM ─────────────────────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // ─── RESET: clear all state ───
            wdt_rst_n     <= 1'b1;           // not in reset
            fault_latched <= 1'b0;
            timeout_cnt   <= {CNT_W{1'b0}};
            last_pc       <= 32'h0000_0000;
            rst_hold      <= 4'd0;
            fault_code    <= 4'b0000; // cleared on reset
            ignore_cnt    <= {IGN_W{1'b0}};
        end else begin
            // always capture previous PC for freeze detection
            last_pc <= pc;

            // advance grace-period counter (stop at FREEZE_IGNORE)
            if (ignore_cnt < FREEZE_IGNORE)
                ignore_cnt <= ignore_cnt + 1'b1;

            // ─── STATE A: reset pulse is currently active ───
            if (!wdt_rst_n) begin
                if (rst_hold == RESET_CYCLES - 1) begin
                    wdt_rst_n <= 1'b1;   // pulse complete → release reset
                    rst_hold  <= 4'd0;
                end else begin
                    rst_hold  <= rst_hold + 1'b1;
                end

            // ─── STATE B: monitoring (latch not yet set) ───
            end else if (!fault_latched) begin

                if (f_trap) begin
                    // P1: TRAP - immediate reset, no counter needed
                    wdt_rst_n     <= 1'b0;
                    fault_latched <= 1'b1;
                    rst_hold      <= 4'd0;
                    timeout_cnt   <= {CNT_W{1'b0}};
                    fault_code    <= cur_fault;

                end else if (any_timed) begin
                    // P2/P3/P4: wait for TIMEOUT cycles then reset
                    if (timeout_cnt == TIMEOUT - 1) begin
                        wdt_rst_n     <= 1'b0;
                        fault_latched <= 1'b1;
                        rst_hold      <= 4'd0;
                        timeout_cnt   <= {CNT_W{1'b0}};
                        fault_code    <= cur_fault;
                    end else begin
                        timeout_cnt <= timeout_cnt + 1'b1;
                    end

                end else begin
                    // no active fault: keep counter clear
                    timeout_cnt <= {CNT_W{1'b0}};
                end

            end
            // ─── STATE C: latched-idle ───
            // fault_latched=1, wdt_rst_n=1
            // No further action until sys_rst_n goes LOW
        end
    end
endmodule
