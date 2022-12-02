// Define pipes that exist in the PipelinedDatapath. 
// The pipe between Writeback (W) and Fetch (F), as well as Fetch (F) and Decode (D) is given to you.
// Create the rest of the pipes where inputs follow the naming conventions in the book.


module PipeFtoD(input logic[31:0] instr, PcPlus4F,
                input logic EN, clear, clk, reset,
                output logic[31:0] instrD, PcPlus4D);

                always_ff @(posedge clk, posedge reset)
                  if(reset)
                        begin
                        instrD <= 0;
                        PcPlus4D <= 0;
                        end
                    else if(EN)
                        begin
                          if(clear) // Can clear only if the pipe is enabled, that is, if it is not stalling.
                            begin
                        	   instrD <= 0;
                        	   PcPlus4D <= 0;
                            end
                          else
                            begin
                        		instrD<=instr;
                        		PcPlus4D<=PcPlus4F;
                            end
                        end
                
endmodule

// Similarly, the pipe between Writeback (W) and Fetch (F) is given as follows.

module PipeWtoF(input logic[31:0] PC,
                input logic EN, clk, reset,		// ~StallF will be connected as this EN
                output logic[31:0] PCF);

                always_ff @(posedge clk, posedge reset)
                    if(reset)
                        PCF <= 0;
                    else if(EN)
                        PCF <= PC;
endmodule

module PipeDtoE(input logic[31:0] RD1, RD2, SignImmD,
                input logic[4:0] RsD, RtD, RdD,
                input logic RegWriteD, MemtoRegD, MemWriteD, ALUSrcD, RegDstD,
                input logic[2:0] ALUControlD,
                input logic clear, clk, reset,
                output logic[31:0] RsData, RtData, SignImmE,
                output logic[4:0] RsE, RtE, RdE, 
                output logic RegWriteE, MemtoRegE, MemWriteE, ALUSrcE, RegDstE,
                output logic[2:0] ALUControlE);

        always_ff @(posedge clk, posedge reset)
          if(reset || clear)
                begin
                // Control signals
                RegWriteE <= 0;
                MemtoRegE <= 0;
                MemWriteE <= 0;
                ALUControlE <= 0;
                ALUSrcE <= 0;
                RegDstE <= 0;
                
                // Data
                RsData <= 0;
                RtData <= 0;
                RsE <= 0;
                RtE <= 0;
                RdE <= 0;
                SignImmE <= 0;
                end
            else
                begin
                // Control signals
                RegWriteE <= RegWriteD;
                MemtoRegE <= MemtoRegD;
                MemWriteE <= MemWriteD;
                ALUControlE <= ALUControlD;
                ALUSrcE <= ALUSrcD;
                RegDstE <= RegDstD;
                
                // Data
                RsData <= RD1;
                RtData <= RD2;
                RsE <= RsD;
                RtE <= RtD;
                RdE <= RdD;
                SignImmE <= SignImmD;
                end

endmodule

module PipeEtoM(input logic RegWriteE, MemtoRegE, MemWriteE,
                input logic [31:0] ALUOutE, WriteDataE,
                input logic [4:0] WriteRegE,
                input logic clk, reset,
                output logic RegWriteM, MemtoRegM, MemWriteM,
                output logic [31:0] ALUOutM, WriteDataM,
                output logic [4:0] WriteRegM);
                    
        always_ff @(posedge clk) 
            if (reset) begin
                    RegWriteM <= 0;
                    MemtoRegM <= 0;
                    MemWriteM <= 0;
                    ALUOutM <= 0;
                    WriteDataM <= 0;
                    WriteRegM <= 0;
           end
           else begin
                    RegWriteM <= RegWriteE;
                    MemtoRegM <= MemtoRegE;
                    MemWriteM <= MemWriteE;
                    ALUOutM <= ALUOutE;
                    WriteDataM <= WriteDataE;
                    WriteRegM <= WriteRegE;
           end
            
            
endmodule

module PipeMtoW(input logic RegWriteM, MemtoRegM,
                input logic [31:0] ReadDataM, ALUOutM,
                input logic [4:0] WriteRegM,
                input logic clk, reset,
                output logic RegWriteW, MemtoRegW,
                output logic [31:0] ReadDataW, ALUOutW,
                output logic [4:0] WriteRegW);
                  
     always_ff @(posedge clk) 
         if (reset) begin
                RegWriteW <= 0;
                MemtoRegW <= 0;
                ReadDataW <= 0;
                ALUOutW <= 0;
                WriteRegW <= 0;
         end  
        
         else begin
                RegWriteW <= RegWriteM;
                MemtoRegW <= MemtoRegM;
                ReadDataW <= ReadDataM;
                ALUOutW <= ALUOutM;
                WriteRegW <= WriteRegM;
         end  
           
                   
endmodule



// *******************************************************************************
// End of the individual pipe definitions.
// ******************************************************************************

// *******************************************************************************
// Below is the definition of the datapath.
// The signature of the module is given. The datapath will include (not limited to) the following items:
//  (1) Adder that adds 4 to PC
//  (2) Shifter that shifts SignImmD to left by 2
//  (3) Sign extender and Register file
//  (4) PipeFtoD
//  (5) PipeDtoE and ALU
//  (5) Adder for PcBranchD
//  (6) PipeEtoM and Data Memory
//  (7) PipeMtoW
//  (8) Many muxes
//  (9) Hazard unit
//  ...?
// *******************************************************************************

module datapath (input  logic clk, reset,
                input  logic[2:0]  ALUControlD,
                input logic RegWriteD, MemtoRegD, MemWriteD, ALUSrcD, RegDstD, BranchD,
                 output logic [31:0] instrF,		
                 output logic [31:0] instrD, PC, PCF,
                output logic PcSrcD,                 
                output logic [31:0] ALUOutE, WriteDataE,
                output logic [1:0] ForwardAE, ForwardBE,
                 output logic ForwardAD, ForwardBD,
                 output logic[5:0] Op, Funct); // Add or remove input-outputs if necessary

	// ********************************************************************
	// Here, define the wires that are needed inside this pipelined datapath module
	// ********************************************************************
  
  	//* We have defined a few wires for you
    logic [31:0] PcSrcA, PcSrcB, PcBranchD, PcPlus4F, PcPlus4D, ResultW, rd1, rd2, ALUOutM, WriteDataM, RsD, RtD, RdD,SrcAE, SrcBE;	
    logic [31:0] rd1Selected, rd2Selected, SignImmD, SignImmDSL2, RsData, RtData, SignImmE, ReadDataW, ALUOutW;
    logic [4:0]  RsE, RtE, RdE, WriteRegE, WriteRegM, WriteRegW;
  	logic StallF, StallD, EqualD, FlushE, RegWriteE, MemtoRegE, MemWriteE, ALUSrcE, RegDstE, zero, RegWriteM, MemtoRegM, MemWriteM, RegWriteW, MemtoRegW;
  	logic [2:0] ALUControlE; 
  
	//* You should define others down below

  
	// ********************************************************************
	// Instantiate the required modules below in the order of the datapath flow.
	// ********************************************************************

  
  	//* We have provided you with some part of the datapath
    
  	// Instantiate PipeWtoF
  	PipeWtoF pipe1(PC,
                ~StallF, clk, reset,
                PCF);
  
  	// Do some operations
    assign PcPlus4F = PCF + 4;
    assign PcSrcB = PcBranchD;
	assign PcSrcA = PcPlus4F;
  	mux2 #(32) pc_mux(PcSrcA, PcSrcB, PcSrcD, PC);

    imem im1(PCF[7:2], instrF);
    
  	// Instantiate PipeFtoD
  	PipeFtoD pipe2(instrF, PcPlus4F,~StallD, PcSrcD, clk, reset,
  	instrD, PcPlus4D);
  
  	// Do some operations
    regfile rf(clk, reset, RegWriteW, 
                    instrD[25:21],instrD[20:16], WriteRegW, 
                    ResultW, 
                    rd1, rd2);
              
    mux2 #(32) mux_AD(rd1, ALUOutM, ForwardAD, rd1Selected);      
    mux2 #(32) mux_BD(rd2, ALUOutM, ForwardBD, rd2Selected); 
    assign EqualD = (rd1Selected == rd2Selected) ? 1'b1 : 1'b0;    
    assign PcSrcD = (EqualD && BranchD) ? 1'b1 : 1'b0;  
    assign Op = instrD[31:26];  
    assign Funct = instrD[5:0];  
    signext sgnExt(instrD[15:0],
                SignImmD);    
    assign SignImmDSL2 = SignImmD << 2; 
    assign PcBranchD = SignImmDSL2 + PcPlus4D;     
    assign RsD = instrD[25:21];
    assign RtD = instrD[20:16];
    assign RdD = instrD[15:11];     
  	// Instantiate PipeDtoE
    PipeDtoE pipe3(rd1Selected, rd2Selected, SignImmD,
                RsD,  RtD, RdD,
                RegWriteD, MemtoRegD, MemWriteD, ALUSrcD, RegDstD,
                ALUControlD,
                FlushE, clk, reset,
                //OUTPUTS
                RsData, RtData, SignImmE,
                RsE, RtE, RdE, 
                RegWriteE, MemtoRegE, MemWriteE, ALUSrcE, RegDstE,
                ALUControlE);
  	// Do some operations
  	
    
     mux2 #(5) mux_writeRegE(RtE, RdE, RegDstE, WriteRegE); 
     mux4 #(32) mux_ForwardAE(RsData, ResultW, ALUOutM, 32'b0,ForwardAE, SrcAE); 
     mux4 #(32) mux_ForwardBE(RtData, ResultW, ALUOutM, 32'b0,ForwardBE, WriteDataE); 
     mux2 #(32) mux_immOrRt(WriteDataE, SignImmE, ALUSrcE, SrcBE); 
     alu alu(SrcAE, SrcBE, 
           ALUControlE, 
           //OUTPUTS
           ALUOutE,
           zero);

  	// Instantiate PipeEtoM
    PipeEtoM pipe4(RegWriteE, MemtoRegE, MemWriteE,
                ALUOutE, WriteDataE,
                WriteRegE,
                clk, reset,
                //OUTPUT
                RegWriteM, MemtoRegM, MemWriteM,
                ALUOutM, WriteDataM,
                WriteRegM);
  	// Do some operations

    dmem dataMem(clk, MemWriteM,
             ALUOutM, WriteDataM,
             //OUTPUT
             ReadDataM);
    
  	// Instantiate PipeMtoW
    
    PipeMtoW pipe5(RegWriteM, MemtoRegM,
                ReadDataM, ALUOutM,
                WriteRegM,
                clk, reset,
                //OUTPUT
                RegWriteW, MemtoRegW,
                ReadDataW, ALUOutW,
                WriteRegW);
  	// Do some operations
  	mux2 #(32) mux_memOrAlu(ALUOutW, ReadDataW, MemtoRegW, ResultW); 
  	
    //HAZARD UNIT INSIANTIATE
    HazardUnit hu( RegWriteW, BranchD,
                WriteRegW, WriteRegE,
                RegWriteM,MemtoRegM,
                WriteRegM,
                RegWriteE,MemtoRegE,
                RsE,RtE,
                RsD,RtD,
                //OUTPUT
                ForwardAE,ForwardBE,
                FlushE,StallD,StallF,ForwardAD, ForwardBD
                 );  
endmodule

module HazardUnit( input logic RegWriteW, BranchD,
                input logic [4:0] WriteRegW, WriteRegE,
                input logic RegWriteM,MemtoRegM,
                input logic [4:0] WriteRegM,
                input logic RegWriteE,MemtoRegE,
                input logic [4:0] rsE,rtE,
                input logic [4:0] rsD,rtD,
                output logic [1:0] ForwardAE,ForwardBE,
                output logic FlushE,StallD,StallF,ForwardAD, ForwardBD
                 ); // Add or remove input-outputs if necessary
       
	// ********************************************************************
	// Here, write equations for the Hazard Logic.
	// If you have troubles, please study pages ~420-430 in your book.
	// ********************************************************************
	logic branchstall, lwstall;
	
always_comb
	
	if ((rsD != 0) && (rsD == WriteRegM) && RegWriteM ) begin
	   assign ForwardAD = 1;
	end
	else begin
	   assign ForwardAD = 0;
	end
	
	//
always_comb	
	if ((rtD != 0) && (rtD == WriteRegM) && RegWriteM ) begin
	   assign ForwardBD = 1;
	end
	else begin
	   assign ForwardBD = 0;
	end
	
	//
always_comb	
    if ((BranchD & RegWriteE && (WriteRegE == rsD || WriteRegE == rtD)) || (BranchD && MemtoRegM && (WriteRegM == rsD || WriteRegM == rtD) )) begin
        assign branchstall = 1;
    end
    else begin
        assign branchstall = 0;
    end
    
    //
   always_comb 
    if (((rsD == rtE) || (rtD == rtE)) && MemtoRegE)begin
	    lwstall = 1;
	end
	else begin
	    lwstall = 0;
	end
	
	//
	always_comb
	if( ((rsE != 0) && (rsE == WriteRegM) && RegWriteM)) begin
	   assign ForwardAE = 10;
	end
	else if( ((rsE != 0) && (rsE == WriteRegW) && RegWriteW)) begin
	   assign ForwardAE = 01;
	end
	else begin
	   assign ForwardAE = 00;
	end
	
	//
	always_comb
	if( ((rtE != 0) && (rtE == WriteRegM) && RegWriteM)) begin
	   assign ForwardBE = 10;
	end
	else if( ((rtE != 0) && (rtE == WriteRegW) && RegWriteW)) begin
	   assign ForwardBE = 01;
	end
	else begin
	   assign ForwardBE = 00;
	end
	    
	//
	always_comb
	assign StallF = (lwstall || branchstall);  
	assign StallD = (lwstall || branchstall);    
	assign FlushE = (lwstall || branchstall);       
	
	
  
endmodule


// You can add some more logic variables for testing purposes
// but you cannot remove existing variables as we need you to output 
// these values on the waveform for grading
module top_mips (input  logic        clk, reset,
             output  logic[31:0]  instrF,
             output logic[31:0] PC, PCF,
             output logic PcSrcD,
             output logic MemWriteD, MemtoRegD, ALUSrcD, BranchD, RegDstD, RegWriteD,
             output logic [2:0]  alucontrol,
             output logic [31:0] instrD, 
             output logic [31:0] ALUOutE, WriteDataE,
             output logic [1:0] ForwardAE, ForwardBE,
                 output logic ForwardAD, ForwardBD);


	// ********************************************************************
	// Below, instantiate a controller and a datapath with their new (if modified) signatures
	// and corresponding connections.
	// ********************************************************************
	logic [5:0] Op, Funct;
	 datapath dp (clk, reset,
               alucontrol,
               RegWriteD, MemtoRegD, MemWriteD, ALUSrcD, RegDstD, BranchD,
                //OUTPUT
               instrF,		
               instrD, PC, PCF,
               PcSrcD,                 
               ALUOutE, WriteDataE,
               ForwardAE, ForwardBE,
               ForwardAD, ForwardBD,
               Op, Funct); 
                 
      controller cont(Op, Funct,
                //OUTPUT
                 MemtoRegD, MemWriteD,
                 ALUSrcD,
                 RegDstD, RegWriteD,
                 alucontrol,
                 BranchD);           
	
  
  
  
endmodule


// External instruction memory used by MIPS
// processor. It models instruction memory as a stored-program 
// ROM, with address as input, and instruction as output
// Modify it to test your own programs.

module imem ( input logic [5:0] addr, output logic [31:0] instr);

// imem is modeled as a lookup table, a stored-program byte-addressable ROM
	always_comb
	   case ({addr,2'b00})		   	// word-aligned fetch
//
// 	***************************************************************************
//	Here, you can paste your own test cases that you prepared for the part 1-e.
//  An example test program is given below.        
//	***************************************************************************
//
//		address		instruction
//		-------		-----------
	   8'h00: instr = 32'h20080007;
       8'h04: instr = 32'h21090005;
       8'h08: instr = 32'h200a0000;
       8'h0c: instr = 32'h210b000f;
       8'h10: instr = 32'h01095020;
       8'h14: instr = 32'h01095025;
       8'h18: instr = 32'h01095024;
       8'h1c: instr = 32'h01095022;
       8'h20: instr = 32'h0109502a;
       8'h24: instr = 32'h8d080000;
       8'h28: instr = 32'h20080007;
       8'h2c: instr = 32'h1100fff5;
       8'h30: instr = 32'h200a000a;
       8'h34: instr = 32'h2009000c;
       default:  instr = {32{1'bx}};	// unknown address
	   endcase
endmodule


// 	***************************************************************************
//	Below are the modules that you shouldn't need to modify at all..
//	***************************************************************************

module controller(input  logic[5:0] op, funct,
                  output logic     memtoreg, memwrite,
                  output logic     alusrc,
                  output logic     regdst, regwrite,
                  output logic[2:0] alucontrol,
                  output logic branch);

   logic [1:0] aluop;

  maindec md (op, memtoreg, memwrite, branch, alusrc, regdst, regwrite, aluop);

   aludec  ad (funct, aluop, alucontrol);

endmodule

// External data memory used by MIPS single-cycle processor

module dmem (input  logic        clk, we,
             input  logic[31:0]  a, wd,
             output logic[31:0]  rd);

   logic  [31:0] RAM[63:0];
  
   assign rd = RAM[a[31:2]];    // word-aligned  read (for lw)

   always_ff @(posedge clk)
     if (we)
       RAM[a[31:2]] <= wd;      // word-aligned write (for sw)

endmodule

module maindec (input logic[5:0] op, 
	              output logic memtoreg, memwrite, branch,
	              output logic alusrc, regdst, regwrite,
	              output logic[1:0] aluop );
  logic [7:0] controls;

   assign {regwrite, regdst, alusrc, branch, memwrite,
                memtoreg,  aluop} = controls;

  always_comb
    case(op)
      6'b000000: controls <= 8'b11000010; // R-type
      6'b100011: controls <= 8'b10100100; // LW
      6'b101011: controls <= 8'b00101000; // SW
      6'b000100: controls <= 8'b00010001; // BEQ
      6'b001000: controls <= 8'b10100000; // ADDI
      default:   controls <= 8'bxxxxxxxx; // illegal op
    endcase
endmodule

module aludec (input    logic[5:0] funct,
               input    logic[1:0] aluop,
               output   logic[2:0] alucontrol);
  always_comb
    case(aluop)
      2'b00: alucontrol  = 3'b010;  // add  (for lw/sw/addi)
      2'b01: alucontrol  = 3'b110;  // sub   (for beq)
      default: case(funct)          // R-TYPE instructions
          6'b100000: alucontrol  = 3'b010; // ADD
          6'b100010: alucontrol  = 3'b110; // SUB
          6'b100100: alucontrol  = 3'b000; // AND
          6'b100101: alucontrol  = 3'b001; // OR
          6'b101010: alucontrol  = 3'b111; // SLT
          default:   alucontrol  = 3'bxxx; // ???
        endcase
    endcase
endmodule

module regfile (input    logic clk, reset, we3, 
                input    logic[4:0]  ra1, ra2, wa3, 
                input    logic[31:0] wd3, 
                output   logic[31:0] rd1, rd2);

  logic [31:0] rf [31:0];

  // three ported register file: read two ports combinationally
  // write third port on falling edge of clock. Register0 hardwired to 0.

  always_ff @(negedge clk)
     if (we3) 
         rf [wa3] <= wd3;
  	 else if(reset)
       for (int i=0; i<32; i++) rf[i] = {32{1'b0}};	

  assign rd1 = (ra1 != 0) ? rf [ra1] : 0;
  assign rd2 = (ra2 != 0) ? rf[ ra2] : 0;

endmodule

module alu(input  logic [31:0] a, b, 
           input  logic [2:0]  alucont, 
           output logic [31:0] result,
           output logic zero);
    
    always_comb
        case(alucont)
            3'b010: result = a + b;
            3'b110: result = a - b;
            3'b000: result = a & b;
            3'b001: result = a | b;
            3'b111: result = (a < b) ? 1 : 0;
            default: result = {32{1'bx}};
        endcase
    
    assign zero = (result == 0) ? 1'b1 : 1'b0;
    
endmodule

module adder (input  logic[31:0] a, b,
              output logic[31:0] y);
     
     assign y = a + b;
endmodule

module sl2 (input  logic[31:0] a,
            output logic[31:0] y);
     
     assign y = {a[29:0], 2'b00}; // shifts left by 2
endmodule

module signext (input  logic[15:0] a,
                output logic[31:0] y);
              
  assign y = {{16{a[15]}}, a};    // sign-extends 16-bit a
endmodule

// parameterized register
module flopr #(parameter WIDTH = 8)
              (input logic clk, reset, 
	       input logic[WIDTH-1:0] d, 
               output logic[WIDTH-1:0] q);

  always_ff@(posedge clk, posedge reset)
    if (reset) q <= 0; 
    else       q <= d;
endmodule


// paramaterized 2-to-1 MUX
module mux2 #(parameter WIDTH = 8)
             (input  logic[WIDTH-1:0] d0, d1,  
              input  logic s, 
              output logic[WIDTH-1:0] y);
  
   assign y = s ? d1 : d0; 
endmodule

// paramaterized 4-to-1 MUX
module mux4 #(parameter WIDTH = 8)
             (input  logic[WIDTH-1:0] d0, d1, d2, d3,
              input  logic[1:0] s, 
              output logic[WIDTH-1:0] y);
  
   assign y = s[1] ? ( s[0] ? d3 : d2 ) : (s[0] ? d1 : d0); 
endmodule