// Dynamic branch predictor: a direct-mapped branch target buffer (BTB) with a 2-bit
// saturating counter per entry, looked up in IF with the current PC.
//   pred_taken = entry valid, tag matches and counter >= 2'b10 (weakly/strongly taken)
// Updated from EX by every resolved branch:
//   hit  -> counter +1 if taken, -1 if not (saturating), target refreshed
//   miss -> allocated only if taken, with counter = 2'b10 (weakly taken)
// clear empties the table (used when instruction memory is rewritten).
module branch_predictor #(
    parameter ENTRIES = 8
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        clear,

    input  wire [31:0] lookup_pc,
    output wire        pred_taken,
    output wire [31:0] pred_target,

    input  wire        update_en,
    input  wire [31:0] update_pc,
    input  wire        update_taken,
    input  wire [31:0] update_target
);

    localparam IW = $clog2(ENTRIES);
    localparam TW = 32 - IW - 2;

    reg [ENTRIES-1:0] valid;
    reg [TW-1:0]      tag     [0:ENTRIES-1];
    reg [31:0]        target  [0:ENTRIES-1];
    reg [1:0]         counter [0:ENTRIES-1];

    wire [IW-1:0] lookup_idx = lookup_pc[IW+1:2];
    wire [IW-1:0] update_idx = update_pc[IW+1:2];
    wire [TW-1:0] lookup_tag = lookup_pc[31:IW+2];
    wire [TW-1:0] update_tag = update_pc[31:IW+2];

    wire lookup_hit = valid[lookup_idx] && (tag[lookup_idx] == lookup_tag);
    wire update_hit = valid[update_idx] && (tag[update_idx] == update_tag);

    assign pred_taken  = lookup_hit && counter[lookup_idx][1];
    assign pred_target = target[lookup_idx];

    integer i;
    initial begin
        for (i = 0; i < ENTRIES; i = i + 1) begin
            tag[i]     = {TW{1'b0}};
            target[i]  = 32'b0;
            counter[i] = 2'b00;
        end
    end

    always @(posedge clk) begin
        if (reset || clear) begin
            valid <= {ENTRIES{1'b0}};
        end
        else if (update_en) begin
            if (update_hit) begin
                if (update_taken && counter[update_idx] != 2'b11) begin
                    counter[update_idx] <= counter[update_idx] + 2'b01;
                end
                else if (!update_taken && counter[update_idx] != 2'b00) begin
                    counter[update_idx] <= counter[update_idx] - 2'b01;
                end
                target[update_idx] <= update_target;
            end
            else if (update_taken) begin
                valid[update_idx]   <= 1'b1;
                tag[update_idx]     <= update_tag;
                target[update_idx]  <= update_target;
                counter[update_idx] <= 2'b10;
            end
        end
    end

endmodule
