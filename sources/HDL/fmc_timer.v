
module fmc_timer(
	rst_n,
//FMC timing
	fmc_clk,fmc_tm_serial,
//Timer for user
	pps_o,
	timer_utc,
	timer_8ns,
	timer_valid); 

//FMC timing
	input rst_n;
	input fmc_clk,fmc_tm_serial;

//Timing
	output reg pps_o;
	output reg [39:0] timer_utc;
	output reg [27:0] timer_8ns;
	output reg timer_valid;

	reg update_8ns;
	reg update_utc;
	reg [39:0] timer_utc_int;
	integer timer_count;

	parameter TIMER_IDLE=2'b00,TIMER_PPS=2'b01,TIMER_UTC_GET=2'b10,TIMER_UTC_UPDATE=2'b11;
	reg [0:1] TIMER_STATE;

always @(posedge fmc_clk)
begin
	if (!rst_n)
		begin
			pps_o<=1'b0;	
			timer_utc<=40'b0;
			timer_8ns<=28'b0;
		end
	else
		begin
			//pps_o<=1'b0;
			timer_8ns<=timer_8ns+28'b1;

			if(timer_8ns == 28'd124999999)
				begin
					//pps_o<=1'b1;
					timer_8ns <= 28'b0;
					timer_utc<=timer_utc+1;
				end
            if(timer_8ns < 28'd500)
                begin
                    pps_o <= 1'b1;
                end
            else
                begin
                    pps_o <= 1'b0;
                end

			if(update_8ns)
				begin
					timer_8ns <= 28'd2;
				end

			if(update_utc)
				begin
					timer_utc <= timer_utc_int;
				end 
		end 
end

always @(posedge fmc_clk) 
begin
	if (!rst_n)
		begin
			update_8ns<=1'b0;
			update_utc<=1'b0;
			timer_valid<=1'b0;
			timer_count<= 0;
			TIMER_STATE<= TIMER_IDLE;
		end
	else
		begin
			case(TIMER_STATE)
			TIMER_IDLE:

				begin

					update_8ns <= 1'b0;
					update_utc <= 1'b0;
					timer_count <= 0;
					
					if(fmc_tm_serial)
						begin
							update_8ns <=1'b1;
							TIMER_STATE <= TIMER_PPS;
						end
				end
			
			TIMER_PPS:
				begin
					update_8ns <= 1'b0;
					TIMER_STATE <= TIMER_UTC_GET;
				end
				
			TIMER_UTC_GET:
				begin
					if(timer_count < 40)
						begin
							timer_count <= timer_count + 1;
							timer_utc_int <= {timer_utc_int[38:0],fmc_tm_serial};
							TIMER_STATE<=TIMER_UTC_GET;
						end
					else
						begin
							TIMER_STATE<=TIMER_UTC_UPDATE;
						end	
				end

			TIMER_UTC_UPDATE:
				begin
					TIMER_STATE<=TIMER_IDLE;
					if(timer_utc==timer_utc_int)
						timer_valid<=1'b1;
					else
						begin
							timer_valid<=1'b0;
							update_utc<=1'b1;
						end
				end
		endcase
	end
end

endmodule