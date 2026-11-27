module cash_inventory_controller #(
    parameter int RECYCLER_CAPACITY = 60,
    parameter int BOX_CAPACITY = 500,
    parameter int SAFE_BOX_THRESHOLD = 400,

    parameter int INIT_NOTE10 = 20,
    parameter int INIT_NOTE20 = 20,
    parameter int INIT_NOTE50 = 10,
    parameter int INIT_NOTE100 = 10,
    parameter int INIT_NOTE200 = 5,
    parameter int INIT_NOTE500 = 2,
    parameter int INIT_COIN5 = 100,

    parameter int MAX_CHANGE = 500,
    parameter int MAX_COMPENSATION = 500
)(
    input  logic clk,
    input  logic rst,

    input  logic new_transaction,
    input  logic clear_transaction,
    input  logic manual_settlement,

    input  logic accepted_note_pulse,
    input  logic [9:0] accepted_note_value,
    input  logic [9:0] candidate_note_value,

    input  logic start_change_plan,
    input  logic start_compensation_plan,
    input  logic abort_planners,

    input  logic [15:0] requested_change,
    input  logic [15:0] compensation_amount,

    input  logic dispense_change,
    input  logic commit_escrow,
    input  logic return_escrow,
    input  logic dispense_compensation,

    output logic note_storage_available,
    output logic escrow_commit_possible,
    output logic escrow_nonempty,
    output logic [15:0] escrow_value,

    output logic change_plan_busy,
    output logic change_plan_done,
    output logic change_possible,

    output logic compensation_plan_busy,
    output logic compensation_plan_done,
    output logic compensation_possible,

    output logic change_done,
    output logic change_failed,

    output logic commit_done,
    output logic commit_failed,

    output logic refund_done,

    output logic compensation_done,
    output logic compensation_failed,

    output logic [15:0] committed_amount,
    output logic [15:0] refund_amount,
    output logic [15:0] change_dispensed_amount,
    output logic [15:0] compensation_dispensed_amount,

    output logic [15:0] refund_10_count,
    output logic [15:0] refund_20_count,
    output logic [15:0] refund_50_count,
    output logic [15:0] refund_100_count,
    output logic [15:0] refund_200_count,
    output logic [15:0] refund_500_count,

    output logic [15:0] dispensed_5_count,
    output logic [15:0] dispensed_10_count,
    output logic [15:0] dispensed_20_count,
    output logic [15:0] dispensed_50_count,
    output logic [15:0] dispensed_100_count,
    output logic [15:0] dispensed_200_count,
    output logic [15:0] dispensed_500_count,

    output logic [15:0] compensation_5_count,
    output logic [15:0] compensation_10_count,
    output logic [15:0] compensation_20_count,
    output logic [15:0] compensation_50_count,
    output logic [15:0] compensation_100_count,
    output logic [15:0] compensation_200_count,
    output logic [15:0] compensation_500_count,

    output logic [16:0] rec1_count,
    output logic [16:0] rec2_count,
    output logic [16:0] rec3_count,

    output logic [9:0] collection_box1_count,
    output logic [9:0] collection_box2_count,

    output logic rec1_full,
    output logic rec2_full,
    output logic rec3_full,

    output logic collection_safe_warning,
    output logic collection_full,

    output logic [15:0] coin5_count,
    output logic [15:0] note10_count,
    output logic [15:0] note20_count,
    output logic [15:0] note50_count,
    output logic [15:0] note100_count,
    output logic [15:0] note200_count,
    output logic [15:0] note500_count
);

    logic [15:0] inv5;
    logic [15:0] inv10;
    logic [15:0] inv20;
    logic [15:0] inv50;
    logic [15:0] inv100;
    logic [15:0] inv200;
    logic [15:0] inv500;

    logic [15:0] escrow_10;
    logic [15:0] escrow_20;
    logic [15:0] escrow_50;
    logic [15:0] escrow_100;
    logic [15:0] escrow_200;
    logic [15:0] escrow_500;

    logic [16:0] rec1_sum;
    logic [16:0] rec2_sum;
    logic [16:0] rec3_sum;

    logic [16:0] refund_effective_10;
    logic [16:0] refund_effective_20;
    logic [16:0] refund_effective_50;
    logic [16:0] refund_effective_100;
    logic [16:0] refund_effective_200;
    logic [16:0] refund_effective_500;
    logic [31:0] refund_effective_value_wide;
    logic [15:0] refund_effective_value;
    logic return_escrow_pulse;

    logic dispense_change_d;
    logic commit_escrow_d;
    logic return_escrow_d;
    logic dispense_compensation_d;

    logic [15:0] change_use_5;
    logic [15:0] change_use_10;
    logic [15:0] change_use_20;
    logic [15:0] change_use_50;
    logic [15:0] change_use_100;
    logic [15:0] change_use_200;
    logic [15:0] change_use_500;

    logic [15:0] compensation_use_5;
    logic [15:0] compensation_use_10;
    logic [15:0] compensation_use_20;
    logic [15:0] compensation_use_50;
    logic [15:0] compensation_use_100;
    logic [15:0] compensation_use_200;
    logic [15:0] compensation_use_500;

    logic [15:0] planned_inv10;
    logic [15:0] planned_inv20;
    logic [15:0] planned_inv50;
    logic [15:0] planned_inv100;
    logic [15:0] planned_inv200;
    logic [15:0] planned_inv500;

    logic [9:0] planned_box1;
    logic [9:0] planned_box2;

    logic change_plan_valid;
    logic compensation_plan_valid;

    logic [31:0] escrow_value_wide;
    logic [31:0] change_plan_amount;
    logic [31:0] compensation_plan_amount;

    integer candidate_10;
    integer candidate_20;
    integer candidate_50;
    integer candidate_100;
    integer candidate_200;
    integer candidate_500;

    integer candidate_overflow;
    integer escrow_overflow;
    integer collection_free;

    integer free1;
    integer free2;
    integer free3;

    integer remaining;
    integer take_count;
    integer overflow_count;

    integer box1_space;
    integer box2_space;
    integer box1_add;
    integer box2_add;

    function automatic integer calculate_overflow(
        input integer c10,
        input integer c20,
        input integer c50,
        input integer c100,
        input integer c200,
        input integer c500
    );

        integer f1;
        integer f2;
        integer f3;

        integer rem;
        integer take;
        integer total;

        begin
            total = 0;

            f2 =
                RECYCLER_CAPACITY -
                (inv10 + inv20);

            if (f2 < 0)
                f2 = 0;

            rem = c10;
            take =
                (rem > f2) ?
                f2 :
                rem;

            rem = rem - take;
            f2  = f2 - take;
            total = total + rem;

            rem = c20;
            take =
                (rem > f2) ?
                f2 :
                rem;

            rem = rem - take;
            total = total + rem;

            f1 =
                RECYCLER_CAPACITY -
                (inv50 + inv100);

            if (f1 < 0)
                f1 = 0;

            rem = c50;
            take =
                (rem > f1) ?
                f1 :
                rem;

            rem = rem - take;
            f1  = f1 - take;
            total = total + rem;

            rem = c100;
            take =
                (rem > f1) ?
                f1 :
                rem;

            rem = rem - take;
            total = total + rem;

            f3 =
                RECYCLER_CAPACITY -
                (inv200 + inv500);

            if (f3 < 0)
                f3 = 0;

            rem = c200;
            take =
                (rem > f3) ?
                f3 :
                rem;

            rem = rem - take;
            f3  = f3 - take;
            total = total + rem;

            rem = c500;
            take =
                (rem > f3) ?
                f3 :
                rem;

            rem = rem - take;
            total = total + rem;

            calculate_overflow =
                total;
        end

    endfunction

    sequential_change_planner #(
        .MAX_AMOUNT(MAX_CHANGE)
    ) u_change_planner (
        .clk(clk),
        .rst(rst),

        .start(start_change_plan),
        .abort_plan(abort_planners),

        .requested_amount(
            requested_change
        ),

        .available_5(inv5),
        .available_10(inv10),
        .available_20(inv20),
        .available_50(inv50),
        .available_100(inv100),
        .available_200(inv200),
        .available_500(inv500),

        .busy(change_plan_busy),
        .done(change_plan_done),
        .possible(change_possible),

        .use_5(change_use_5),
        .use_10(change_use_10),
        .use_20(change_use_20),
        .use_50(change_use_50),
        .use_100(change_use_100),
        .use_200(change_use_200),
        .use_500(change_use_500)
    );

    sequential_change_planner #(
        .MAX_AMOUNT(MAX_COMPENSATION)
    ) u_compensation_planner (
        .clk(clk),
        .rst(rst),

        .start(
            start_compensation_plan
        ),

        .abort_plan(
            abort_planners
        ),

        .requested_amount(
            compensation_amount
        ),

        .available_5(inv5),
        .available_10(inv10),
        .available_20(inv20),
        .available_50(inv50),
        .available_100(inv100),
        .available_200(inv200),
        .available_500(inv500),

        .busy(
            compensation_plan_busy
        ),

        .done(
            compensation_plan_done
        ),

        .possible(
            compensation_possible
        ),

        .use_5(
            compensation_use_5
        ),

        .use_10(
            compensation_use_10
        ),

        .use_20(
            compensation_use_20
        ),

        .use_50(
            compensation_use_50
        ),

        .use_100(
            compensation_use_100
        ),

        .use_200(
            compensation_use_200
        ),

        .use_500(
            compensation_use_500
        )
    );

    always_comb begin
        candidate_10  = escrow_10;
        candidate_20  = escrow_20;
        candidate_50  = escrow_50;
        candidate_100 = escrow_100;
        candidate_200 = escrow_200;
        candidate_500 = escrow_500;

        case (candidate_note_value)
            10'd10:
                candidate_10 =
                    candidate_10 + 1;

            10'd20:
                candidate_20 =
                    candidate_20 + 1;

            10'd50:
                candidate_50 =
                    candidate_50 + 1;

            10'd100:
                candidate_100 =
                    candidate_100 + 1;

            10'd200:
                candidate_200 =
                    candidate_200 + 1;

            10'd500:
                candidate_500 =
                    candidate_500 + 1;

            default: begin
            end
        endcase

        candidate_overflow =
            calculate_overflow(
                candidate_10,
                candidate_20,
                candidate_50,
                candidate_100,
                candidate_200,
                candidate_500
            );

        escrow_overflow =
            calculate_overflow(
                escrow_10,
                escrow_20,
                escrow_50,
                escrow_100,
                escrow_200,
                escrow_500
            );

        collection_free =
            (2 * BOX_CAPACITY) -
            collection_box1_count -
            collection_box2_count;

        case (candidate_note_value)
            10'd10,
            10'd20,
            10'd50,
            10'd100,
            10'd200,
            10'd500:
                note_storage_available =
                    candidate_overflow <=
                    collection_free;

            default:
                note_storage_available =
                    1'b0;
        endcase

        escrow_commit_possible =
            escrow_overflow <=
            collection_free;

        escrow_nonempty =
            (escrow_10  != 0) ||
            (escrow_20  != 0) ||
            (escrow_50  != 0) ||
            (escrow_100 != 0) ||
            (escrow_200 != 0) ||
            (escrow_500 != 0);

        escrow_value_wide =
            (escrow_10  * 10)  +
            (escrow_20  * 20)  +
            (escrow_50  * 50)  +
            (escrow_100 * 100) +
            (escrow_200 * 200) +
            (escrow_500 * 500);

        if (escrow_value_wide > 16'hFFFF)
            escrow_value = 16'hFFFF;
        else
            escrow_value =
                escrow_value_wide[15:0];
    end

    always_comb begin
        return_escrow_pulse =
            return_escrow &&
            !return_escrow_d;

        refund_effective_10 =
            {1'b0, escrow_10} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd10) ?
             17'd1 : 17'd0);

        refund_effective_20 =
            {1'b0, escrow_20} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd20) ?
             17'd1 : 17'd0);

        refund_effective_50 =
            {1'b0, escrow_50} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd50) ?
             17'd1 : 17'd0);

        refund_effective_100 =
            {1'b0, escrow_100} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd100) ?
             17'd1 : 17'd0);

        refund_effective_200 =
            {1'b0, escrow_200} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd200) ?
             17'd1 : 17'd0);

        refund_effective_500 =
            {1'b0, escrow_500} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd500) ?
             17'd1 : 17'd0);

        refund_effective_value_wide =
            (refund_effective_10  * 10)  +
            (refund_effective_20  * 20)  +
            (refund_effective_50  * 50)  +
            (refund_effective_100 * 100) +
            (refund_effective_200 * 200) +
            (refund_effective_500 * 500);

        if (
            refund_effective_value_wide >
            32'd65535
        )
            refund_effective_value =
                16'hFFFF;
        else
            refund_effective_value =
                refund_effective_value_wide[15:0];
    end

    always_comb begin
        planned_inv10  = inv10;
        planned_inv20  = inv20;
        planned_inv50  = inv50;
        planned_inv100 = inv100;
        planned_inv200 = inv200;
        planned_inv500 = inv500;

        planned_box1 =
            collection_box1_count;

        planned_box2 =
            collection_box2_count;

        overflow_count = 0;

        free2 =
            RECYCLER_CAPACITY -
            (inv10 + inv20);

        if (free2 < 0)
            free2 = 0;

        remaining = escrow_10;

        take_count =
            (remaining > free2) ?
            free2 :
            remaining;

        planned_inv10 =
            inv10 + take_count;

        remaining =
            remaining -
            take_count;

        free2 =
            free2 -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        remaining = escrow_20;

        take_count =
            (remaining > free2) ?
            free2 :
            remaining;

        planned_inv20 =
            inv20 + take_count;

        remaining =
            remaining -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        free1 =
            RECYCLER_CAPACITY -
            (inv50 + inv100);

        if (free1 < 0)
            free1 = 0;

        remaining = escrow_50;

        take_count =
            (remaining > free1) ?
            free1 :
            remaining;

        planned_inv50 =
            inv50 + take_count;

        remaining =
            remaining -
            take_count;

        free1 =
            free1 -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        remaining = escrow_100;

        take_count =
            (remaining > free1) ?
            free1 :
            remaining;

        planned_inv100 =
            inv100 + take_count;

        remaining =
            remaining -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        free3 =
            RECYCLER_CAPACITY -
            (inv200 + inv500);

        if (free3 < 0)
            free3 = 0;

        remaining = escrow_200;

        take_count =
            (remaining > free3) ?
            free3 :
            remaining;

        planned_inv200 =
            inv200 + take_count;

        remaining =
            remaining -
            take_count;

        free3 =
            free3 -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        remaining = escrow_500;

        take_count =
            (remaining > free3) ?
            free3 :
            remaining;

        planned_inv500 =
            inv500 + take_count;

        remaining =
            remaining -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        box1_space =
            BOX_CAPACITY -
            collection_box1_count;

        box2_space =
            BOX_CAPACITY -
            collection_box2_count;

        box1_add =
            (overflow_count > box1_space) ?
            box1_space :
            overflow_count;

        overflow_count =
            overflow_count -
            box1_add;

        box2_add =
            (overflow_count > box2_space) ?
            box2_space :
            overflow_count;

        planned_box1 =
            collection_box1_count +
            box1_add;

        planned_box2 =
            collection_box2_count +
            box2_add;
    end

    always_comb begin
        change_plan_amount =
            (change_use_5   * 5)   +
            (change_use_10  * 10)  +
            (change_use_20  * 20)  +
            (change_use_50  * 50)  +
            (change_use_100 * 100) +
            (change_use_200 * 200) +
            (change_use_500 * 500);

        compensation_plan_amount =
            (compensation_use_5   * 5)   +
            (compensation_use_10  * 10)  +
            (compensation_use_20  * 20)  +
            (compensation_use_50  * 50)  +
            (compensation_use_100 * 100) +
            (compensation_use_200 * 200) +
            (compensation_use_500 * 500);

        change_plan_valid =
            change_possible &&
            (change_use_5   <= inv5)   &&
            (change_use_10  <= inv10)  &&
            (change_use_20  <= inv20)  &&
            (change_use_50  <= inv50)  &&
            (change_use_100 <= inv100) &&
            (change_use_200 <= inv200) &&
            (change_use_500 <= inv500) &&
            (
                change_plan_amount ==
                requested_change
            );

        compensation_plan_valid =
            compensation_possible &&
            (compensation_use_5   <= inv5)   &&
            (compensation_use_10  <= inv10)  &&
            (compensation_use_20  <= inv20)  &&
            (compensation_use_50  <= inv50)  &&
            (compensation_use_100 <= inv100) &&
            (compensation_use_200 <= inv200) &&
            (compensation_use_500 <= inv500) &&
            (
                compensation_plan_amount ==
                compensation_amount
            );
    end

    always_comb begin
        rec1_sum =
            {1'b0, inv50} +
            {1'b0, inv100};

        rec2_sum =
            {1'b0, inv10} +
            {1'b0, inv20};

        rec3_sum =
            {1'b0, inv200} +
            {1'b0, inv500};

        rec1_count = rec1_sum;
        rec2_count = rec2_sum;
        rec3_count = rec3_sum;

        rec1_full =
            rec1_sum >=
            $unsigned(RECYCLER_CAPACITY);

        rec2_full =
            rec2_sum >=
            $unsigned(RECYCLER_CAPACITY);

        rec3_full =
            rec3_sum >=
            $unsigned(RECYCLER_CAPACITY);

        collection_safe_warning =
            (collection_box1_count >=
             SAFE_BOX_THRESHOLD) ||
            (collection_box2_count >=
             SAFE_BOX_THRESHOLD);

        collection_full =
            (collection_box1_count >=
             BOX_CAPACITY) &&
            (collection_box2_count >=
             BOX_CAPACITY);

        coin5_count  = inv5;
        note10_count = inv10;
        note20_count = inv20;
        note50_count = inv50;
        note100_count = inv100;
        note200_count = inv200;
        note500_count = inv500;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            inv5   <= INIT_COIN5;
            inv10  <= INIT_NOTE10;
            inv20  <= INIT_NOTE20;
            inv50  <= INIT_NOTE50;
            inv100 <= INIT_NOTE100;
            inv200 <= INIT_NOTE200;
            inv500 <= INIT_NOTE500;

            collection_box1_count <= 10'd0;
            collection_box2_count <= 10'd0;

            escrow_10  <= 16'd0;
            escrow_20  <= 16'd0;
            escrow_50  <= 16'd0;
            escrow_100 <= 16'd0;
            escrow_200 <= 16'd0;
            escrow_500 <= 16'd0;

            dispense_change_d       <= 1'b0;
            commit_escrow_d         <= 1'b0;
            return_escrow_d         <= 1'b0;
            dispense_compensation_d <= 1'b0;

            change_done         <= 1'b0;
            change_failed       <= 1'b0;
            commit_done         <= 1'b0;
            commit_failed       <= 1'b0;
            refund_done         <= 1'b0;
            compensation_done   <= 1'b0;
            compensation_failed <= 1'b0;

            committed_amount <= 16'd0;
            refund_amount <= 16'd0;
            change_dispensed_amount <= 16'd0;
            compensation_dispensed_amount <=
                16'd0;

            refund_10_count  <= 16'd0;
            refund_20_count  <= 16'd0;
            refund_50_count  <= 16'd0;
            refund_100_count <= 16'd0;
            refund_200_count <= 16'd0;
            refund_500_count <= 16'd0;

            dispensed_5_count   <= 16'd0;
            dispensed_10_count  <= 16'd0;
            dispensed_20_count  <= 16'd0;
            dispensed_50_count  <= 16'd0;
            dispensed_100_count <= 16'd0;
            dispensed_200_count <= 16'd0;
            dispensed_500_count <= 16'd0;

            compensation_5_count   <= 16'd0;
            compensation_10_count  <= 16'd0;
            compensation_20_count  <= 16'd0;
            compensation_50_count  <= 16'd0;
            compensation_100_count <= 16'd0;
            compensation_200_count <= 16'd0;
            compensation_500_count <= 16'd0;
        end else begin
            dispense_change_d <=
                dispense_change;

            commit_escrow_d <=
                commit_escrow;

            return_escrow_d <=
                return_escrow;

            dispense_compensation_d <=
                dispense_compensation;

            change_done         <= 1'b0;
            change_failed       <= 1'b0;
            commit_done         <= 1'b0;
            commit_failed       <= 1'b0;
            refund_done         <= 1'b0;
            compensation_done   <= 1'b0;
            compensation_failed <= 1'b0;

            if (new_transaction) begin
                committed_amount <= 16'd0;
                refund_amount <= 16'd0;
                change_dispensed_amount <= 16'd0;
                compensation_dispensed_amount <=
                    16'd0;

                refund_10_count  <= 16'd0;
                refund_20_count  <= 16'd0;
                refund_50_count  <= 16'd0;
                refund_100_count <= 16'd0;
                refund_200_count <= 16'd0;
                refund_500_count <= 16'd0;

                dispensed_5_count   <= 16'd0;
                dispensed_10_count  <= 16'd0;
                dispensed_20_count  <= 16'd0;
                dispensed_50_count  <= 16'd0;
                dispensed_100_count <= 16'd0;
                dispensed_200_count <= 16'd0;
                dispensed_500_count <= 16'd0;

                compensation_5_count   <= 16'd0;
                compensation_10_count  <= 16'd0;
                compensation_20_count  <= 16'd0;
                compensation_50_count  <= 16'd0;
                compensation_100_count <= 16'd0;
                compensation_200_count <= 16'd0;
                compensation_500_count <= 16'd0;
            end

            if (clear_transaction) begin
                dispense_change_d       <= 1'b0;
                commit_escrow_d         <= 1'b0;
                return_escrow_d         <= 1'b0;
                dispense_compensation_d <= 1'b0;
            end

            if (manual_settlement) begin
                escrow_10  <= 16'd0;
                escrow_20  <= 16'd0;
                escrow_50  <= 16'd0;
                escrow_100 <= 16'd0;
                escrow_200 <= 16'd0;
                escrow_500 <= 16'd0;
            end

            if (
                accepted_note_pulse &&
                !return_escrow_pulse
            ) begin
                case (accepted_note_value)
                    10'd10:
                        escrow_10 <=
                            escrow_10 + 1'b1;

                    10'd20:
                        escrow_20 <=
                            escrow_20 + 1'b1;

                    10'd50:
                        escrow_50 <=
                            escrow_50 + 1'b1;

                    10'd100:
                        escrow_100 <=
                            escrow_100 + 1'b1;

                    10'd200:
                        escrow_200 <=
                            escrow_200 + 1'b1;

                    10'd500:
                        escrow_500 <=
                            escrow_500 + 1'b1;

                    default: begin
                    end
                endcase
            end

            if (
                commit_escrow &&
                !commit_escrow_d
            ) begin
                if (
                    escrow_commit_possible
                ) begin
                    committed_amount <=
                        escrow_value;

                    inv10  <= planned_inv10;
                    inv20  <= planned_inv20;
                    inv50  <= planned_inv50;
                    inv100 <= planned_inv100;
                    inv200 <= planned_inv200;
                    inv500 <= planned_inv500;

                    collection_box1_count <=
                        planned_box1;

                    collection_box2_count <=
                        planned_box2;

                    escrow_10  <= 16'd0;
                    escrow_20  <= 16'd0;
                    escrow_50  <= 16'd0;
                    escrow_100 <= 16'd0;
                    escrow_200 <= 16'd0;
                    escrow_500 <= 16'd0;

                    commit_done <= 1'b1;
                end else begin
                    commit_failed <= 1'b1;
                end
            end

            if (
                dispense_change &&
                !dispense_change_d
            ) begin
                if (change_plan_valid) begin
                    inv5 <=
                        inv5 -
                        change_use_5;

                    inv10 <=
                        inv10 -
                        change_use_10;

                    inv20 <=
                        inv20 -
                        change_use_20;

                    inv50 <=
                        inv50 -
                        change_use_50;

                    inv100 <=
                        inv100 -
                        change_use_100;

                    inv200 <=
                        inv200 -
                        change_use_200;

                    inv500 <=
                        inv500 -
                        change_use_500;

                    dispensed_5_count <=
                        change_use_5;

                    dispensed_10_count <=
                        change_use_10;

                    dispensed_20_count <=
                        change_use_20;

                    dispensed_50_count <=
                        change_use_50;

                    dispensed_100_count <=
                        change_use_100;

                    dispensed_200_count <=
                        change_use_200;

                    dispensed_500_count <=
                        change_use_500;

                    change_dispensed_amount <=
                        requested_change;

                    change_done <= 1'b1;
                end else begin
                    change_failed <= 1'b1;
                end
            end

            if (return_escrow_pulse) begin
                refund_10_count <=
                    refund_effective_10[16] ?
                    16'hFFFF :
                    refund_effective_10[15:0];

                refund_20_count <=
                    refund_effective_20[16] ?
                    16'hFFFF :
                    refund_effective_20[15:0];

                refund_50_count <=
                    refund_effective_50[16] ?
                    16'hFFFF :
                    refund_effective_50[15:0];

                refund_100_count <=
                    refund_effective_100[16] ?
                    16'hFFFF :
                    refund_effective_100[15:0];

                refund_200_count <=
                    refund_effective_200[16] ?
                    16'hFFFF :
                    refund_effective_200[15:0];

                refund_500_count <=
                    refund_effective_500[16] ?
                    16'hFFFF :
                    refund_effective_500[15:0];

                refund_amount <=
                    refund_effective_value;

                escrow_10  <= 16'd0;
                escrow_20  <= 16'd0;
                escrow_50  <= 16'd0;
                escrow_100 <= 16'd0;
                escrow_200 <= 16'd0;
                escrow_500 <= 16'd0;

                refund_done <= 1'b1;
            end

            if (
                dispense_compensation &&
                !dispense_compensation_d
            ) begin
                if (
                    compensation_plan_valid
                ) begin
                    inv5 <=
                        inv5 -
                        compensation_use_5;

                    inv10 <=
                        inv10 -
                        compensation_use_10;

                    inv20 <=
                        inv20 -
                        compensation_use_20;

                    inv50 <=
                        inv50 -
                        compensation_use_50;

                    inv100 <=
                        inv100 -
                        compensation_use_100;

                    inv200 <=
                        inv200 -
                        compensation_use_200;

                    inv500 <=
                        inv500 -
                        compensation_use_500;

                    compensation_5_count <=
                        compensation_use_5;

                    compensation_10_count <=
                        compensation_use_10;

                    compensation_20_count <=
                        compensation_use_20;

                    compensation_50_count <=
                        compensation_use_50;

                    compensation_100_count <=
                        compensation_use_100;

                    compensation_200_count <=
                        compensation_use_200;

                    compensation_500_count <=
                        compensation_use_500;

                    compensation_dispensed_amount <=
                        compensation_amount;

                    compensation_done <= 1'b1;
                end else begin
                    compensation_failed <= 1'b1;
                end
            end
        end
    end

`ifdef FORMAL
    // P9 and related mutual-exclusion checks.
    // These assertions are active only in a formal run (compile with -DFORMAL).
    always_ff @(posedge clk) begin
        if (!rst) begin
            // P9: change and compensation are never dispensed together.
            assert (!(dispense_change && dispense_compensation));

            // Only one planner request may be launched at a time.
            assert (!(start_change_plan && start_compensation_plan));
            if (start_change_plan)
                assert (!(change_plan_busy || compensation_plan_busy));
            if (start_compensation_plan)
                assert (!(change_plan_busy || compensation_plan_busy));

            // Escrow commit, refund and dispensing are separate operations.
            assert (!(commit_escrow && return_escrow));
            assert (!(commit_escrow && dispense_change));
            assert (!(commit_escrow && dispense_compensation));
            assert (!(return_escrow && dispense_change));
            assert (!(return_escrow && dispense_compensation));

            // A dispense request can only consume a validated exact plan.
            if (dispense_change && !dispense_change_d)
                assert (change_plan_valid);
            if (dispense_compensation && !dispense_compensation_d)
                assert (compensation_plan_valid);
        end
    end
`endif

`ifndef SYNTHESIS
    initial begin
        assert (RECYCLER_CAPACITY > 0)
            else $fatal("RECYCLER_CAPACITY must be positive");

        assert (RECYCLER_CAPACITY <= 65535)
            else $fatal("RECYCLER_CAPACITY must fit in 16-bit inventories");

        assert (INIT_NOTE10 >= 0 && INIT_NOTE10 <= 65535)
            else $fatal("INIT_NOTE10 must fit in 16 bits and cannot be negative");

        assert (INIT_NOTE20 >= 0 && INIT_NOTE20 <= 65535)
            else $fatal("INIT_NOTE20 must fit in 16 bits and cannot be negative");

        assert (INIT_NOTE50 >= 0 && INIT_NOTE50 <= 65535)
            else $fatal("INIT_NOTE50 must fit in 16 bits and cannot be negative");

        assert (INIT_NOTE100 >= 0 && INIT_NOTE100 <= 65535)
            else $fatal("INIT_NOTE100 must fit in 16 bits and cannot be negative");

        assert (INIT_NOTE200 >= 0 && INIT_NOTE200 <= 65535)
            else $fatal("INIT_NOTE200 must fit in 16 bits and cannot be negative");

        assert (INIT_NOTE500 >= 0 && INIT_NOTE500 <= 65535)
            else $fatal("INIT_NOTE500 must fit in 16 bits and cannot be negative");

        assert (INIT_COIN5 >= 0 && INIT_COIN5 <= 65535)
            else $fatal("INIT_COIN5 must fit in 16 bits and cannot be negative");

        assert (
            INIT_NOTE50 + INIT_NOTE100 <=
            RECYCLER_CAPACITY
        ) else $fatal("Initial recycler 1 inventory exceeds capacity");

        assert (
            INIT_NOTE10 + INIT_NOTE20 <=
            RECYCLER_CAPACITY
        ) else $fatal("Initial recycler 2 inventory exceeds capacity");

        assert (
            INIT_NOTE200 + INIT_NOTE500 <=
            RECYCLER_CAPACITY
        ) else $fatal("Initial recycler 3 inventory exceeds capacity");

        assert (BOX_CAPACITY > 0)
            else $fatal("BOX_CAPACITY must be positive");

        assert (BOX_CAPACITY <= 1023)
            else $fatal("BOX_CAPACITY must fit in 10 bits");

        assert (SAFE_BOX_THRESHOLD >= 0)
            else $fatal("SAFE_BOX_THRESHOLD cannot be negative");

        assert (SAFE_BOX_THRESHOLD <= BOX_CAPACITY)
            else $fatal("SAFE_BOX_THRESHOLD cannot exceed BOX_CAPACITY");
    end
`endif

endmodule

// ============================================================================
// System-level safety-property checker for the smart ticket vending machine.
//
// Compile this module with FORMAL defined and instantiate it in the top-level
// vending-machine module. The cash inventory controller alone does not contain
// the payment FSM, card controller, ticket registry, gate interface, or complete
// accounting totals; therefore P1-P8 must be connected to their real top-level
// signals before they can be checked.
//
// RECOVERY_BOUND is the maximum permitted number of clock cycles to complete
// escrow recovery, card rollback, and FSM recovery after the relevant trigger.
//
// P1: money_in = fare_kept + change_returned + refund_returned
//                      + compensation_paid, at transaction_settled.
// P2: no ticket is issued without payment_success_this_transaction.
// P3: an aborted transaction with escrow must be refunded or enter service_error.
// P4: a failed transaction after card debit must roll back or enter service_error.
// P5: a used/invalid ticket must never open the gate.
// P6: accepted requests must belong to the current transaction epoch.
// P7: accounting counters saturate and raise overflow rather than wrapping.
// P8: after inputs stop, the FSM reaches IDLE or SERVICE_ERROR within the bound.
// P9 is checked directly inside cash_inventory_controller above.
// ============================================================================

`ifdef FORMAL
module smart_ticket_safety_checker #(
    parameter int RECOVERY_BOUND = 16,
    parameter int COUNTER_W = 32,
    parameter int ACCOUNTING_COUNTERS = 4
)(
    input  logic clk,
    input  logic rst,

    // P1: per-transaction totals, in the same currency unit.
    // transaction_settled is a one-cycle pulse at the final accounting point
    // for either a completed or an aborted transaction.
    input  logic transaction_settled,
    input  logic [31:0] money_in,
    input  logic [31:0] fare_kept,
    // These amounts must be confirmed delivered/returned, not merely requested.
    input  logic [31:0] change_returned,
    input  logic [31:0] refund_returned,
    input  logic [31:0] compensation_paid,

    // P2: this signal must mean payment succeeded in this same transaction.
    input  logic ticket_issued,
    input  logic payment_success_this_transaction,

    // P3: abort and escrow recovery.
    input  logic transaction_aborted,
    input  logic escrow_nonempty,
    // Assert only after physical escrow return is confirmed by the dispenser.
    // The current cash_inventory_controller refund_done pulse is a logical
    // bookkeeping event, not a physical-dispenser acknowledgement.
    input  logic escrow_return_confirmed,
    input  logic service_error,

    // P4: card debit rollback.
    input  logic card_debit_success,
    input  logic transaction_failed,
    input  logic transaction_completed,
    input  logic card_rollback_done,

    // P5: gate authorization. gate_open should be the one-cycle gate-grant pulse,
    // and the scanned-ticket status must refer to the same ticket on that cycle.
    input  logic gate_open,
    input  logic scanned_ticket_valid,
    input  logic scanned_ticket_used,

    // P6: stale request rejection.
    input  logic request_accepted,
    input  logic [15:0] request_epoch,
    input  logic [15:0] current_epoch,

    // P7: packed accounting counters and their update/overflow indicators.
    // Counter i occupies accounting_counters[i*COUNTER_W +: COUNTER_W].
    input  logic [ACCOUNTING_COUNTERS*COUNTER_W-1:0] accounting_counters,
    input  logic [ACCOUNTING_COUNTERS-1:0] accounting_increment,
    input  logic [ACCOUNTING_COUNTERS-1:0] accounting_overflow,

    // P8: inputs_stopped must include no new external request and no pending
    // peripheral response that is allowed to keep the FSM progressing.
    input  logic inputs_stopped,
    input  logic fsm_idle,
    input  logic fsm_service_error
);

    localparam int WATCHDOG_W =
        (RECOVERY_BOUND < 2) ? 1 : $clog2(RECOVERY_BOUND + 1);

    logic [33:0] accounted_total;

    logic abort_pending;
    logic [WATCHDOG_W-1:0] abort_count;

    logic card_debit_pending;
    logic rollback_pending;
    logic [WATCHDOG_W-1:0] rollback_count;

    logic [WATCHDOG_W-1:0] fsm_recovery_count;


    always_comb begin
        accounted_total =
            {2'b00, fare_kept} +
            {2'b00, change_returned} +
            {2'b00, refund_returned} +
            {2'b00, compensation_paid};
    end

    // P1-P4 and P8 monitor state.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            abort_pending       <= 1'b0;
            abort_count         <= '0;
            card_debit_pending  <= 1'b0;
            rollback_pending    <= 1'b0;
            rollback_count      <= '0;
            fsm_recovery_count  <= '0;
        end else begin
            // P1: check the full money-conservation equation at settlement.
            if (transaction_settled)
                assert (accounted_total == {2'b00, money_in});

            // P2: never issue a ticket without same-transaction payment.
            if (ticket_issued)
                assert (payment_success_this_transaction);

            // P3: an abort with escrow must reach refund_done or service_error.
            if (!abort_pending && transaction_aborted && escrow_nonempty) begin
                if (escrow_return_confirmed || service_error) begin
                    abort_pending <= 1'b0;
                    abort_count   <= '0;
                end else begin
                    abort_pending <= 1'b1;
                    abort_count   <= '0;
                end
            end else if (abort_pending) begin
                if (escrow_return_confirmed || service_error) begin
                    abort_pending <= 1'b0;
                    abort_count   <= '0;
                end else begin
                    assert (abort_count < RECOVERY_BOUND);
                    abort_count <= abort_count + 1'b1;
                end
            end

            // P4: remember a successful debit. If its transaction fails, require
            // rollback or escalation to service_error within RECOVERY_BOUND cycles.
            if (rollback_pending) begin
                if (card_rollback_done || service_error) begin
                    rollback_pending <= 1'b0;
                    rollback_count   <= '0;
                end else begin
                    assert (rollback_count < RECOVERY_BOUND);
                    rollback_count <= rollback_count + 1'b1;
                end
            end else if (transaction_failed &&
                         (card_debit_pending || card_debit_success)) begin
                card_debit_pending <= 1'b0;
                if (card_rollback_done || service_error) begin
                    rollback_pending <= 1'b0;
                    rollback_count   <= '0;
                end else begin
                    rollback_pending <= 1'b1;
                    rollback_count   <= '0;
                end
            end else begin
                if (card_debit_success)
                    card_debit_pending <= 1'b1;
                if (transaction_completed)
                    card_debit_pending <= 1'b0;
            end

            // P8: bounded recovery after all external inputs/responses stop.
            if (!inputs_stopped || fsm_idle || fsm_service_error) begin
                fsm_recovery_count <= '0;
            end else begin
                assert (fsm_recovery_count < RECOVERY_BOUND);
                fsm_recovery_count <= fsm_recovery_count + 1'b1;
            end
        end
    end

    // P5: even a scanned ticket must be valid and unused before gate opening.
    always_ff @(posedge clk) begin
        if (!rst && gate_open)
            assert (scanned_ticket_valid && !scanned_ticket_used);
    end

    // P6: the controller must not accept requests from an old transaction.
    always_ff @(posedge clk) begin
        if (!rst && request_accepted)
            assert (request_epoch == current_epoch);
    end

    // P7: if a counter was at maximum and an increment was requested, its value
    // must remain saturated and its overflow indicator must be raised next cycle.
    generate
        for (genvar c = 0; c < ACCOUNTING_COUNTERS; c++) begin : g_counter_safety
            logic overflow_expected;
            wire [COUNTER_W-1:0] counter_value =
                accounting_counters[c*COUNTER_W +: COUNTER_W];

            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    overflow_expected <= 1'b0;
                end else begin
                    if (overflow_expected) begin
                        assert (&counter_value);
                        assert (accounting_overflow[c]);
                    end
                    overflow_expected <=
                        accounting_increment[c] && (&counter_value);
                end
            end
        end
    endgenerate

    // Elaboration-time parameter check.
    initial begin
        assert (RECOVERY_BOUND >= 1);
        assert (COUNTER_W >= 1);
        assert (ACCOUNTING_COUNTERS >= 1);
    end

endmodule
`endif

