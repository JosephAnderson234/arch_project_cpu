`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.11.2025 16:54:20
// Design Name: 
// Module Name: mul_floating_points
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module mul2_vector_mul( input [31:0] a_value, input [31:0] b_value, input[31:0] c_value, input[31:0] d_value, output [31:0] result_value );

    wire [31:0] temp_result1;
    wire [31:0] temp_result2;

    mul_floating_points mul_inst1 (
        .a_value(a_value),
        .b_value(c_value),
        .result_value(temp_result1)
    );

    mul_floating_points mul_inst2 (
        .a_value(b_value),
        .b_value(d_value),
        .result_value(temp_result2)
    );

    sum_floating_points sum_inst (
        .a_value(temp_result1),
        .b_value(temp_result2),
        .result_value(result_value)
    );

endmodule