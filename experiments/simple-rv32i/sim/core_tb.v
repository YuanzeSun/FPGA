`timescale 1ns/1ps
module core_tb;
    reg clk=0, reset=1;
    always #5 clk=~clk;
    wire valid, fetch, trap;
    wire [31:0] addr,wdata,trap_cause,trap_value,pc,retired;
    wire [3:0] mask;
    reg ready=0, error=0;
    reg [31:0] rdata=0;
    rv32_core cpu(clk,reset,valid,fetch,addr,wdata,mask,ready,error,rdata,
                  trap,trap_cause,trap_value,pc,retired,,,,,);
    reg [31:0] rom[0:2047], ram[0:255];
    string image,prefix;
    integer i,fd,md,cycles=0,delay_left=0;
    reg pending=0;
    reg [31:0] saved_addr,saved_data;
    reg [3:0] saved_mask;
    initial begin
        if (!$value$plusargs("image=%s",image) || !$value$plusargs("prefix=%s",prefix)) $fatal(1,"Missing paths");
        $readmemh(image,rom);
        for(i=0;i<256;i=i+1) ram[i]=32'h80ff7f01^(i*32'h01020304);
        fd=$fopen({prefix,".trace"},"w");
        repeat(4) @(negedge clk); reset=0;
    end
    always @(posedge clk) begin
        cycles <= cycles+1; ready<=0; error<=0;
        if (!reset) begin
            if(pending) begin
                if(!valid || addr!==saved_addr || wdata!==saved_data || mask!==saved_mask) $fatal(1,"Unstable bus request");
                if(delay_left!=0) delay_left<=delay_left-1;
                else begin
                    pending<=0; ready<=1;
                    if(saved_addr<32'h2000 && saved_mask==0) rdata<=rom[saved_addr[12:2]];
                    else if(saved_addr>=32'h10000 && saved_addr<32'h10400) begin
                        rdata<=ram[saved_addr[9:2]];
                        for(i=0;i<4;i=i+1) if(saved_mask[i]) ram[saved_addr[9:2]][8*i+:8]<=saved_data[8*i+:8];
                    end else begin error<=1; rdata<=0; end
                end
            end else if(valid && !ready) begin
                pending<=1; delay_left<=cycles%4;
                saved_addr<=addr; saved_data<=wdata; saved_mask<=mask;
            end
        end
        #1;
        if(!reset && cpu.retire_valid) $fdisplay(fd,"%08x %08x %02x %08x",cpu.retire_pc,cpu.retire_instr,cpu.retire_rd,cpu.retire_data);
        if(!reset && trap) begin
            $fclose(fd); md=$fopen({prefix,".memory"},"w");
            for(i=0;i<256;i=i+1) $fdisplay(md,"%08x",ram[i]);
            $fclose(md);
            $display("TRAP %08x %08x %08x RETIRED %0d",trap_cause,trap_value,pc,retired);
            $finish;
        end
        if(cycles>100000) $fatal(1,"CPU timeout");
    end
endmodule
