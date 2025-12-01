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


module mul_floating_points(
    input[31:0] a_value, input[31:0] b_value, output[31:0] result_value
    );

    //i should multiplyl 2 numbers that is given in IEEE 754 floating point format

    wire a_sign;
    wire b_sign;
    wire res_sign;
    
    wire[7:0] a_exponent;
    wire[7:0] b_exponent;
    wire[7:0] res_exponent;
    wire[22:0] a_mantissa;
    wire[22:0] b_mantissa;
    wire[47:0] res_mantissa;
    wire[23:0] a_mantissa_with_hidden_bit;
    wire[23:0] b_mantissa_with_hidden_bit;
    wire[47:0] mantissa_product;
    wire[7:0] exponent_sum;
    wire normalize;
    wire[22:0] final_mantissa;
    wire[7:0] final_exponent;
    wire overflow;
    assign a_sign = a_value[31];
    assign b_sign = b_value[31];
    assign a_exponent = a_value[30:23];
    assign b_exponent = b_value[30:23];
    assign a_mantissa = a_value[22:0];
    assign b_mantissa = b_value[22:0];
    assign a_mantissa_with_hidden_bit = {1'b1, a_mantissa};
    assign b_mantissa_with_hidden_bit = {1'b1, b_mantissa};
    assign mantissa_product = a_mantissa_with_hidden_bit * b_mantissa_with_hidden_bit;
    assign exponent_sum = a_exponent + b_exponent - 8'd127;
    assign normalize = mantissa_product[47];
    assign res_sign = a_sign ^ b_sign;
    assign res_exponent = normalize ? (exponent_sum + 8'd1) : exponent_sum;
    assign final_mantissa = normalize ? mantissa_product[46:24] : mantissa_product[45:23];
    assign overflow = (res_exponent >= 8'd255);
    assign final_exponent = overflow ? 8'd255 : res_exponent;
    assign result_value = {res_sign, final_exponent, final_mantissa};
endmodule
