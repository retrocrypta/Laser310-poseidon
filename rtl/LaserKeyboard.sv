module LaserKeyboard(
input wire				CLK50MHZ,
input wire	[15:0]	CPU_A,
input wire				RESET,
input wire				CASS_IN,
input wire				PS2_KBCLK,
input wire				PS2_KBDAT
);


// keyboard
reg		[4:0]		KB_CLK;
reg		[16:0]		RESET_KEY_COUNT;
wire	[7:0]		SCAN;
wire				PRESS;
wire				PRESS_N;
wire				EXTENDED;
reg					BOOTROM_EN;
reg		[7:0]		BOOTROM_BANK;
reg					AUTOSTARTROM_EN;
reg		[7:0]		AUTOSTARTROM_BANK;
reg		[63:0]		KEY;
reg		[9:0]		KEY_EX;
reg		[11:0]		KEY_Fxx;
wire	[7:0]		KEY_DATA;
//reg	[63:0]		LAST_KEY;
//reg				CAPS_CLK;
//reg				CAPS;
wire				A_KEY_PRESSED;

reg		[7:0]		LATCHED_KEY_DATA;

// emu keyboard
wire	[63:0]		EMU_KEY;
wire	[9:0]		EMU_KEY_EX;
wire				EMU_KEY_EN;
// keyboard

/*****************************************************************************
* Convert PS/2 keyboard to ASCII keyboard
******************************************************************************/

/*
   KD5 KD4 KD3 KD2 KD1 KD0 扫描用地址
A0  R   Q   E       W   T  68FEH       0
A1  F   A   D  CTRL S   G  68FDH       8
A2  V   Z   C  SHFT X   B  68FBH      16
A3  4   1   3       2   5  68F7H      24
A4  M  空格 ，      .   N  68EFH      32
A5  7   0   8   -   9   6  68DFH      40
A6  U   P   I  RETN O   Y  68BFH      48
A7  J   ；  K   :   L   H  687FH      56
*/

//  7: 0
// 15: 8
// 23:16
// 31:24
// 39:32
// 47:40
// 55:48
// 63:56



// 键盘检测的方法，就是循环地问每一行线发送低电平信号，也就是用该地址线为“0”的地址去读取数据。
// 例如，检测第一行时，使A0为0，其余为1；加上选通IC4的高五位地址01101，成为01101***11111110B（A8~A10不起作用，
// 可为任意值，故68FEH，69FEH，6AFEH，6BFEH，6CFEH，6DFEH，6EFEH，6FFEH均可）。
// 读 6800H 判断是否有按键按下。

// The method of keyboard detection is to cyclically ask each line to send a low level signal, 
// that is, to read the data with the address line "0".
// For example, when detecting the first line, make A0 0 and the rest 1; plus the high five-bit address 01101 of the strobe IC4, 
// become 01101***11111110B (A8~A10 does not work,
// It can be any value, so 68FEH, 69FEH, 6AFEH, 6BFEH, 6CFEH, 6DFEH, 6EFEH, 6FFEH can be).
// Read 6800H to determine if there is a button press.

// 键盘选通，整个竖列有一个选通的位置被按下，对应值为0。
// The keyboard is strobed, and a strobe position is pressed in the entire vertical column, and the corresponding value is 0.

// 键盘扩展
// 加入方向键盘
// Keyboard extension

// left:  ctrl M      37 KEY_EX[5]
// right: ctrl ,      35 KEY_EX[6]
// up:    ctrl .      33 KEY_EX[4]
// down:  ctrl space  36 KEY_EX[7]
// esc:   ctrl -      42 KEY_EX[3]
// backspace:  ctrl M      37 KEY_EX[8]

// R-Shift


wire	[63:0]	KEY_C		=	EMU_KEY_EN?EMU_KEY:KEY;
wire	[9:0]	KEY_EX_C	=	EMU_KEY_EN?EMU_KEY_EX:KEY_EX;

//wire KEY_CTRL_ULRD = (KEY_EX[7:4]==4'b1111);
wire KEY_CTRL_ULRD_BRK = (KEY_EX[8:3]==6'b111111);

wire KEY_DATA_BIT5 = (CPU_A[7:0]|{KEY_C[61], KEY_C[53], KEY_C[45],           KEY_C[37]&KEY_EX_C[5]&KEY_EX_C[8], KEY_C[29], KEY_C[21],           KEY_C[13],                   KEY_C[ 5]})==8'hff;
wire KEY_DATA_BIT4 = (CPU_A[7:0]|{KEY_C[60], KEY_C[52], KEY_C[44],           KEY_C[36]&KEY_EX_C[7], KEY_C[28], KEY_C[20],           KEY_C[12],                   KEY_C[ 4]})==8'hff;
wire KEY_DATA_BIT3 = (CPU_A[7:0]|{KEY_C[59], KEY_C[51], KEY_C[43],           KEY_C[35]&KEY_EX_C[6], KEY_C[27], KEY_C[19],           KEY_C[11],                   KEY_C[ 3]})==8'hff;
wire KEY_DATA_BIT2 = (CPU_A[7:0]|{KEY_C[58], KEY_C[50], KEY_C[42]&KEY_EX_C[3], KEY_C[34],           KEY_C[26], KEY_C[18]&KEY_EX_C[0], KEY_C[10]&KEY_CTRL_ULRD_BRK, KEY_C[ 2]})==8'hff;
wire KEY_DATA_BIT1 = (CPU_A[7:0]|{KEY_C[57], KEY_C[49], KEY_C[41],           KEY_C[33]&KEY_EX_C[4], KEY_C[25], KEY_C[17],           KEY_C[ 9],                   KEY_C[ 1]})==8'hff;
wire KEY_DATA_BIT0 = (CPU_A[7:0]|{KEY_C[56], KEY_C[48], KEY_C[40],           KEY_C[32],             KEY_C[24], KEY_C[16],           KEY_C[ 8],                   KEY_C[ 0]})==8'hff;

/*
wire KEY_DATA_BIT5 = (CPU_A[7:0]|{KEY[61], KEY[53], KEY[45], KEY[37], KEY[29], KEY[21], KEY[13], KEY[ 5]})==8'hff;
wire KEY_DATA_BIT4 = (CPU_A[7:0]|{KEY[60], KEY[52], KEY[44], KEY[36], KEY[28], KEY[20], KEY[12], KEY[ 4]})==8'hff;
wire KEY_DATA_BIT3 = (CPU_A[7:0]|{KEY[59], KEY[51], KEY[43], KEY[35], KEY[27], KEY[19], KEY[11], KEY[ 3]})==8'hff;
wire KEY_DATA_BIT2 = (CPU_A[7:0]|{KEY[58], KEY[50], KEY[42], KEY[34], KEY[26], KEY[18], KEY[10], KEY[ 2]})==8'hff;
wire KEY_DATA_BIT1 = (CPU_A[7:0]|{KEY[57], KEY[49], KEY[41], KEY[33], KEY[25], KEY[17], KEY[ 9], KEY[ 1]})==8'hff;
wire KEY_DATA_BIT0 = (CPU_A[7:0]|{KEY[56], KEY[48], KEY[40], KEY[32], KEY[24], KEY[16], KEY[ 8], KEY[ 0]})==8'hff;
*/

wire KEY_DATA_BIT7 = 1'b1;	// 没有空置，具体用途没有理解
//wire KEY_DATA_BIT6 = CASS_IN;
wire KEY_DATA_BIT6 = ~CASS_IN;

assign KEY_DATA = { KEY_DATA_BIT7, KEY_DATA_BIT6, KEY_DATA_BIT5, KEY_DATA_BIT4, KEY_DATA_BIT3, KEY_DATA_BIT2, KEY_DATA_BIT1, KEY_DATA_BIT0 };

/*
assign KEY_DATA = 	(CPU_A[0]==1'b0) ? KEY[ 7: 0] :
					(CPU_A[1]==1'b0) ? KEY[15: 8] :
					(CPU_A[2]==1'b0) ? KEY[23:16] :
					(CPU_A[3]==1'b0) ? KEY[31:24] :
					(CPU_A[4]==1'b0) ? KEY[39:32] :
					(CPU_A[5]==1'b0) ? KEY[47:40] :
					(CPU_A[6]==1'b0) ? KEY[55:48] :
					(CPU_A[7]==1'b0) ? KEY[63:56] :
					8'hff;

assign KEY_DATA =
					(CPU_A[7]==1'b0) ? KEY[63:56] :
					(CPU_A[6]==1'b0) ? KEY[55:48] :
					(CPU_A[5]==1'b0) ? KEY[47:40] :
					(CPU_A[4]==1'b0) ? KEY[39:32] :
					(CPU_A[3]==1'b0) ? KEY[31:24] :
					(CPU_A[2]==1'b0) ? KEY[23:16] :
					(CPU_A[1]==1'b0) ? KEY[15: 8] :
					(CPU_A[0]==1'b0) ? KEY[ 7: 0] :
					8'hff;
*/


assign A_KEY_PRESSED = (KEY[63:0] == 64'hFFFFFFFFFFFFFFFF) ? 1'b0:1'b1;

always @(posedge KB_CLK[3] or negedge RESET)
begin
	if(~RESET)
	begin
		KEY					<=	64'hFFFFFFFFFFFFFFFF;
		KEY_EX				<=	10'h3FF;
		KEY_Fxx				<=	12'h000;
//		CAPS_CLK			<=	1'b0;
		RESET_KEY_COUNT		<=	17'h1FFFF;

		BOOTROM_BANK		<=	0;
		BOOTROM_EN			<=	1'b0;

		AUTOSTARTROM_BANK	<=	0;
		AUTOSTARTROM_EN		<=	1'b0;
	end
	else
	begin
		//KEY[?] <= CAPS;
		if(RESET_KEY_COUNT[16]==1'b0)
			RESET_KEY_COUNT <= RESET_KEY_COUNT+1;

		case(SCAN)
		/*8'h07:
		begin
				KEY_Fxx[11]	<= PRESS;	// F12 RESET
				if(PRESS && (KEY[10]==PRESS_N))
				begin
					BOOTROM_EN			<=	1'b0;
					BOOTROM_BANK		<=	0;
					AUTOSTARTROM_EN		<=	1'b0;
					AUTOSTARTROM_BANK	<=	0;
					RESET_KEY_COUNT		<=	17'h0;
				end
		end
		8'h78:	KEY_Fxx[10] <= PRESS;	// F11
		8'h09:	KEY_Fxx[ 9] <= PRESS;	// F10 CASS STOP
		8'h01:	KEY_Fxx[ 8] <= PRESS;	// F9  CASS PLAY
		8'h0A:
		begin
				KEY_Fxx[ 7] <= PRESS;	// F8  Ctrl or L-Shift BOOT 8
				if(PRESS && (KEY[18]==PRESS_N))
				begin
					BOOTROM_EN			<=	1'b1;
					BOOTROM_BANK		<=	39;
					RESET_KEY_COUNT		<=	17'h0;
				end
				else
				if(PRESS && (KEY[10]==PRESS_N))
				begin
					AUTOSTARTROM_EN		<=	1'b1;
					AUTOSTARTROM_BANK	<=	23;
					RESET_KEY_COUNT		<=	17'h0;
				end
		end
		8'h83:
		begin
				KEY_Fxx[ 6] <= PRESS;	// F7  Ctrl or L-Shift BOOT 7
				if(PRESS && (KEY[18]==PRESS_N))
				begin
					BOOTROM_EN			<=	1'b1;
					BOOTROM_BANK		<=	38;
					RESET_KEY_COUNT		<=	17'h0;
				end
				else
				if(PRESS && (KEY[10]==PRESS_N))
				begin
					AUTOSTARTROM_EN		<=	1'b1;
					AUTOSTARTROM_BANK	<=	22;
					RESET_KEY_COUNT		<=	17'h0;
				end
		end
		8'h0B:
		begin
				KEY_Fxx[ 5] <= PRESS;	// F6  Ctrl or L-Shift BOOT 6
				if(PRESS && (KEY[18]==PRESS_N))
				begin
					BOOTROM_EN			<=	1'b1;
					BOOTROM_BANK		<=	37;
					RESET_KEY_COUNT		<=	17'h0;
				end
				else
				if(PRESS && (KEY[10]==PRESS_N))
				begin
					AUTOSTARTROM_EN		<=	1'b1;
					AUTOSTARTROM_BANK	<=	21;
					RESET_KEY_COUNT		<=	17'h0;
				end
		end
		8'h03:
		begin
				KEY_Fxx[ 4] <= PRESS;	// F5  Ctrl or L-Shift BOOT 5
				if(PRESS && (KEY[18]==PRESS_N))
				begin
					BOOTROM_EN			<=	1'b1;
					BOOTROM_BANK		<=	36;
					RESET_KEY_COUNT		<=	17'h0;
				end
				else
				if(PRESS && (KEY[10]==PRESS_N))
				begin
					AUTOSTARTROM_EN		<=	1'b1;
					AUTOSTARTROM_BANK	<=	20;
					RESET_KEY_COUNT		<=	17'h0;
				end
		end
		8'h0C:
		begin
				KEY_Fxx[ 3] <= PRESS;	// F4  Ctrl or L-Shift BOOT 4
				if(PRESS && (KEY[18]==PRESS_N))
				begin
					BOOTROM_EN			<=	1'b1;
					BOOTROM_BANK		<=	35;
					RESET_KEY_COUNT		<=	17'h0;
				end
				else
				if(PRESS && (KEY[10]==PRESS_N))
				begin
					AUTOSTARTROM_EN		<=	1'b1;
					AUTOSTARTROM_BANK	<=	19;
					RESET_KEY_COUNT		<=	17'h0;
				end
		end
		8'h04:
		begin
				KEY_Fxx[ 2] <= PRESS;	// F3  Ctrl or L-Shift BOOT 3
				if(PRESS && (KEY[18]==PRESS_N))
				begin
					BOOTROM_EN			<=	1'b1;
					BOOTROM_BANK		<=	34;
					RESET_KEY_COUNT		<=	17'h0;
				end
				else
				if(PRESS && (KEY[10]==PRESS_N))
				begin
					AUTOSTARTROM_EN		<=	1'b1;
					AUTOSTARTROM_BANK	<=	18;
					RESET_KEY_COUNT		<=	17'h0;
				end
		end
		8'h06:
		begin
				KEY_Fxx[ 1] <= PRESS;	// F2  Ctrl or L-Shift BOOT 2
				if(PRESS && (KEY[18]==PRESS_N))
				begin
					BOOTROM_EN			<=	1'b1;
					BOOTROM_BANK		<=	33;
					RESET_KEY_COUNT		<=	17'h0;
				end
				else
				if(PRESS && (KEY[10]==PRESS_N))
				begin
					AUTOSTARTROM_EN		<=	1'b1;
					AUTOSTARTROM_BANK	<=	17;
					RESET_KEY_COUNT		<=	17'h0;
				end
		end
		8'h05:
		begin
				KEY_Fxx[ 0] <= PRESS;	// F1  Ctrl or L-Shift BOOT 1
				if(PRESS && (KEY[18]==PRESS_N))
				begin
					BOOTROM_EN			<=	1'b1;
					BOOTROM_BANK		<=	32;
					RESET_KEY_COUNT		<=	17'h0;
				end
				else
				if(PRESS && (KEY[10]==PRESS_N))
				begin
					AUTOSTARTROM_EN		<=	1'b1;
					AUTOSTARTROM_BANK	<=	16;
					RESET_KEY_COUNT		<=	17'h0;
				end
		end*/

		8'h16:	KEY[28] <= PRESS_N;	// 1 !
		8'h1E:	KEY[25] <= PRESS_N;	// 2 @
		8'h26:	KEY[27] <= PRESS_N;	// 3 #
		8'h25:	KEY[29] <= PRESS_N;	// 4 $
		8'h2E:	KEY[24] <= PRESS_N;	// 5 %
		8'h36:	KEY[40] <= PRESS_N;	// 6 ^
		8'h3D:	KEY[45] <= PRESS_N;	// 7 &
//		8'h0D:	KEY[?] <= PRESS_N;	// TAB
		8'h3E:	KEY[43] <= PRESS_N;	// 8 *
		8'h46:	KEY[41] <= PRESS_N;	// 9 (
		8'h45:	KEY[44] <= PRESS_N;	// 0 )
		8'h4E:	KEY[42] <= PRESS_N;	// - _
//		8'h55:	KEY[?] <= PRESS_N;	// = +
		8'h66:	KEY_EX[8] <= PRESS_N;	// backspace
//		8'h0E:	KEY[?] <= PRESS_N;	// ` ~
//		8'h5D:	KEY[?] <= PRESS_N;	// \ |
		8'h49:	KEY[33] <= PRESS_N;	// . >
		8'h4b:	KEY[57] <= PRESS_N;	// L
		8'h44:	KEY[49] <= PRESS_N;	// O
//		8'h11	KEY[?] <= PRESS_N; // line feed (really right ALT (Extended) see below
		8'h5A:	KEY[50] <= PRESS_N;	// CR
//		8'h54:	KEY[?] <= PRESS_N;	// [ {
//		8'h5B:	KEY[?] <= PRESS_N;	// ] }
		8'h52:	KEY[58] <= PRESS_N;	// ' "
		8'h1D:	KEY[ 1] <= PRESS_N;	// W
		8'h24:	KEY[ 3] <= PRESS_N;	// E
		8'h2D:	KEY[ 5] <= PRESS_N;	// R
		8'h2C:	KEY[ 0] <= PRESS_N;	// T
		8'h35:	KEY[48] <= PRESS_N;	// Y
		8'h3C:	KEY[53] <= PRESS_N;	// U
		8'h43:	KEY[51] <= PRESS_N;	// I
		8'h1B:	KEY[ 9] <= PRESS_N;	// S
		8'h23:	KEY[11] <= PRESS_N;	// D
		8'h2B:	KEY[13] <= PRESS_N;	// F
		8'h34:	KEY[ 8] <= PRESS_N;	// G
		8'h33:	KEY[56] <= PRESS_N;	// H
		8'h3B:	KEY[61] <= PRESS_N;	// J
		8'h42:	KEY[59] <= PRESS_N;	// K
		8'h22:	KEY[17] <= PRESS_N;	// X
		8'h21:	KEY[19] <= PRESS_N;	// C
		8'h2a:	KEY[21] <= PRESS_N;	// V
		8'h32:	KEY[16] <= PRESS_N;	// B
		8'h31:	KEY[32] <= PRESS_N;	// N
		8'h3a:	KEY[37] <= PRESS_N;	// M
		8'h41:	KEY[35] <= PRESS_N;	// , <
		8'h15:	KEY[ 4] <= PRESS_N;	// Q
		8'h1C:	KEY[12] <= PRESS_N;	// A
		8'h1A:	KEY[20] <= PRESS_N;	// Z
		8'h29:	KEY[36] <= PRESS_N;	// Space
//		8'h4A:	KEY[?] <= PRESS_N;	// / ?
		8'h4C:	KEY[60] <= PRESS_N;	// ; :
		8'h4D:	KEY[52] <= PRESS_N;	// P
		8'h14:	KEY[10] <= PRESS_N;	// Ctrl either left or right
		8'h12:	KEY[18] <= PRESS_N;	// L-Shift
		8'h59:	KEY_EX[0] <= PRESS_N;	// R-Shift
		8'h11:
		begin
			if(~EXTENDED)
					KEY_EX[1] <= PRESS_N;	// Repeat really left ALT
			else
					KEY_EX[2] <= PRESS_N;	// LF really right ALT
		end
		8'h76:	KEY_EX[3] <= PRESS_N;	// Esc
		8'h75:	KEY_EX[4] <= PRESS_N;	// up
		8'h6B:	KEY_EX[5] <= PRESS_N;	// left
		8'h74:	KEY_EX[6] <= PRESS_N;	// right
		8'h72:	KEY_EX[7] <= PRESS_N;	// down
		endcase
	end
end




always @ (posedge CLK50MHZ)				// 50MHz
	KB_CLK <= KB_CLK + 1'b1;			// 50/32 = 1.5625 MHz

ps2_keyboard KEYBOARD(
		.RESET_N(~RESET),
		.CLK(KB_CLK[4]),
		.PS2_CLK(PS2_KBCLK),
		.PS2_DATA(PS2_KBDAT),
		.RX_SCAN(SCAN),
		.RX_PRESSED(PRESS),
		.RX_EXTENDED(EXTENDED)
);

assign PRESS_N = ~PRESS;


endmodule 
