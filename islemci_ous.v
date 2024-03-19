`timescale 1ns/1ps

`define BELLEK_ADRES    32'h8000_0000
`define VERI_BIT        32
`define ADRES_BIT       32
`define YAZMAC_SAYISI   32

module islemci_ous (
    input                       clk,
    input                       rst,
    output  [`ADRES_BIT-1:0]    bellek_adres,
    input   [`VERI_BIT-1:0]     bellek_oku_veri,
    output  [`VERI_BIT-1:0]     bellek_yaz_veri,
    output                     bellek_yaz
);

localparam GETIR        = 2'd0;
localparam COZYAZMACOKU = 2'd1;
localparam YURUTGERIYAZ = 2'd2;

reg [31:0] veri = 32'h0;
reg yazma_denetimi = 1'b0;
reg [1:0] simdiki_asama_r = 0;
reg [1:0] simdiki_asama_ns;
reg ilerle_cmb;
reg [`VERI_BIT-1:0] buyruk;
reg [`VERI_BIT-1:0] yazmac_obegi [0:`YAZMAC_SAYISI-1];
reg [`ADRES_BIT-1:0] ps_r;
reg [`ADRES_BIT-1:0] ps_keep;
reg [`VERI_BIT-1:0] rs1;
reg [`VERI_BIT-1:0] rs2;
reg [`VERI_BIT-1:0] rd;
reg [4:0] rd_adres;
reg [4:0] rs1_adres;
reg [2:0] amb_islem;
reg [11:0] imm_i_type;
reg [11:0] imm_s_type;
reg [19:0] imm_u_type;
reg [19:0] imm_j_type;
reg [19:0] imm_b_type;
reg [3:0] buyruk_tipi;
reg [31:0] genisletilmis;
reg dallan;
reg [4:0] length;
reg bigger;
reg [`VERI_BIT-1:0] bellek_verisi;
initial begin
    yazmac_obegi[0] = 0;
    ps_r = 0;
    veri = 32'h0;
    yazma_denetimi = 1'b0;
end

always @ * begin
    ilerle_cmb = 1;
    simdiki_asama_ns = simdiki_asama_r;
    //$display("simdiki_asama: %h", simdiki_asama_ns);
    if(simdiki_asama_ns == 0) begin
        ilerle_cmb = 1;        
    end else if(simdiki_asama_ns == 1) begin
         if(buyruk[6:0] == 7'b0110011) begin
            if(buyruk[14:12] == 3'b000) begin
                if(buyruk[31:25] == 7'b0000000) begin
                    buyruk_tipi = 4'b0100;
                end else if(buyruk[31:25] == 7'b0100000) begin
                    buyruk_tipi = 4'b0011;
                end
            end else if(buyruk[14:12] == 3'b110) begin
                buyruk_tipi = 4'b0010;
            end else if(buyruk[14:12] == 3'b111) begin
                buyruk_tipi = 4'b0001;
            end else if(buyruk[14:12] == 3'b100) begin
                buyruk_tipi = 4'b0000;
            end
        end else if(buyruk[6:0] == 7'b0010011) begin
            imm_i_type = buyruk[31:20];
            buyruk_tipi = 4'b0101;
        end else if(buyruk[6:0] == 7'b0100011) begin
            imm_s_type = {buyruk[31:25], buyruk[11:7]};
            genisletilmis = {{20{imm_s_type[11]}}, imm_s_type};
            rs1 = yazmac_obegi[buyruk[19:15]];
            rs2 = yazmac_obegi[buyruk[24:20]];
            buyruk_tipi = 4'b0110;     
        end else if(buyruk[6:0] == 7'b0000011) begin   
            imm_i_type = buyruk[31:20];
            rd_adres = buyruk[11:7];
            rs1 = yazmac_obegi[buyruk[19:15]];
            genisletilmis = {{20{imm_i_type[11]}}, imm_i_type};
            buyruk_tipi = 4'b0111;
        end else if(buyruk[6:0] == 7'b1100011) begin
            imm_b_type = {buyruk[31], buyruk[7], buyruk[30:25], buyruk[11:8]};
            buyruk_tipi = 4'b1000;
        end else if(buyruk[6:0] == 7'b1100111) begin
            imm_i_type = buyruk[31:20];
            buyruk_tipi = 4'b1001;
        end else if(buyruk[6:0] == 7'b1101111) begin
            buyruk_tipi = 4'b1010;
            imm_j_type = {buyruk[31], buyruk[19:12], buyruk[20], buyruk[30:21]};
        end else if(buyruk[6:0] == 7'b0010111) begin
            buyruk_tipi = 4'b1011;
            imm_u_type = buyruk[31:12];       
        end else if(buyruk[6:0] == 7'b0110111) begin
            imm_u_type = buyruk[31:12];
            buyruk_tipi = 4'b1100;
        end else if(buyruk[6:0] == 7'b1110011) begin
            if(buyruk[14:12] == 3'b001) begin
                //ks
                buyruk_tipi = 4'b1101;
                bigger = 1;
            end else if(buyruk[14:12] == 3'b010)begin
                //dg
                buyruk_tipi = 4'b1110;
            end
        end
    end else if(simdiki_asama_ns == 2) begin
        case(buyruk_tipi)
            4'b1100: begin
                //lui
                genisletilmis = {imm_u_type, {12{1'b0}}};
            end
            4'b1010: begin
                //jal
                genisletilmis = {{20{imm_j_type[19]}}, imm_u_type};
            end
            4'b1010: begin
                //jalr
                genisletilmis = {{20{imm_i_type[11]}}, imm_i_type};
            end 
            4'b0101: begin
                //addi
                genisletilmis = {{20{imm_i_type[11]}}, imm_i_type};
            end
            4'b1000: begin
                //beq
                genisletilmis = {{20{imm_b_type[11]}}, imm_b_type};
                dallan = rs1 - rs2 == 0 ? 1'b1 : 1'b0;
            end
            4'b1011: begin
                //auipc
                genisletilmis = {imm_u_type, {12{1'b0}}};
            end
            4'b0111: begin
                //lw
                bellek_verisi = bellek_oku_veri;
            end   
            4'b0110: begin
                //sw
                yazma_denetimi = 1;
                veri = rs2;
            end
            4'b1101: begin
                //ks
                if(bigger) begin
                    yazmac_obegi[rd_adres] <= yazmac_obegi[rs1_adres];
                end
                ilerle_cmb = length == 0 ? 1'b1 : 1'b0;
            end
            4'b1110: begin
                //ds
                ilerle_cmb = length == 0 ? 1'b1 : 1'b0;         
            end
        endcase
    end
end
always @(posedge clk) begin
    if (rst) begin
        ps_r <= `BELLEK_ADRES;
        simdiki_asama_r <= GETIR;
    end
    else begin
        if (ilerle_cmb) begin
            if(simdiki_asama_ns == 0) begin
                simdiki_asama_r <= 1;
                ps_r <= ps_r + 4;
                buyruk <= bellek_oku_veri;
            end else if(simdiki_asama_ns == 1) begin
                case(buyruk_tipi)
                    4'b0000: begin
                        //XOR
                        rs1 <= yazmac_obegi[buyruk[19:15]];
                        rs2 <= yazmac_obegi[buyruk[24:20]];
                        rd_adres <= buyruk[11:7];
                        amb_islem <= 3'b100; 
                    end
                    4'b0001: begin
                        //AND
                        rs1 <= yazmac_obegi[buyruk[19:15]];
                        rs2 <= yazmac_obegi[buyruk[24:20]];
                        rd_adres <= buyruk[11:7];
                        amb_islem <= 3'b011; 
                    end
                    4'b0010: begin
                        //OR
                        rs1 <= yazmac_obegi[buyruk[19:15]];
                        rs2 <= yazmac_obegi[buyruk[24:20]];
                        rd_adres <= buyruk[11:7];
                        amb_islem <= 3'b010; 
                    end
                    4'b0011: begin
                        //SUB
                        rs1 <= yazmac_obegi[buyruk[19:15]];
                        rs2 <= yazmac_obegi[buyruk[24:20]];
                        rd_adres <= buyruk[11:7];
                        amb_islem <= 3'b001; 
                    end
                    4'b0100: begin
                        //ADD
                        rs1 <= yazmac_obegi[buyruk[19:15]];
                        rs2 <= yazmac_obegi[buyruk[24:20]];
                        rd_adres <= buyruk[11:7];
                        amb_islem <= 3'b000; 
                    end
                    4'b0101: begin
                        //ADDI
                        rs1 <= yazmac_obegi[buyruk[19:15]];
                        rs2 <= yazmac_obegi[buyruk[24:20]];
                        rd_adres <= buyruk[11:7];
                    end
                    4'b0110: begin
                        //SW
                        ps_keep <= ps_r;
                        yazma_denetimi <= 1;
                        veri <= rs2;
                        ps_r <= genisletilmis + rs1;
                    end
                    4'b0111: begin
                        //LW
                        yazma_denetimi <= 0;
                        ps_keep <= ps_r;
                        ps_r <= genisletilmis + rs1;                     
                    end
                    4'b1000: begin
                        //BEQ
                        rs1 <= yazmac_obegi[buyruk[19:15]];
                        rs2 <= yazmac_obegi[buyruk[24:20]];
                    end
                    4'b1001: begin
                        //JALR
                        rd_adres <= buyruk[11:7];
                        rs1 <= yazmac_obegi[buyruk[19:15]];
                    end
                    4'b1010: begin
                        //JAL
                        rd_adres <= buyruk[11:7];
                    end
                    4'b1011: begin
                        //AUIPC
                        rd_adres <= buyruk[11:7];
                    end
                    4'b1100: begin
                        //LUI
                        rd_adres <= buyruk[11:7];
                    end
                    4'b1101: begin
                        //KS
                        length <= buyruk[24:20];
                        rs1_adres <= buyruk[19:15];
                        rd_adres <= buyruk[11:7];
                    end
                    4'b1110: begin
                        //DS
                        //length deðeri 0 olduðunda iþleme girmediði için en baþta 1 arttýrýyorum.
                        length <= buyruk[24:20] + 1;
                        rs1_adres <= buyruk[19:15];
                        rd_adres <= buyruk[11:7];
                        ps_keep <= ps_r;
                    end
                endcase
                simdiki_asama_r <= 2;    
            end else if(simdiki_asama_ns == 2) begin    
                if(buyruk_tipi <= 4'b0100) begin
                    case(amb_islem)
                        3'b000: yazmac_obegi[rd_adres] <= rs1 + rs2; 
                        3'b001: yazmac_obegi[rd_adres] <= rs1 - rs2; 
                        3'b010: yazmac_obegi[rd_adres] <= rs1 | rs2; 
                        3'b011: yazmac_obegi[rd_adres] <= rs1 & rs2; 
                        3'b100: yazmac_obegi[rd_adres] <= rs1 ^ rs2; 
                    endcase
                    
                end else if(buyruk_tipi == 4'b0101) begin
                    //addi
                    yazmac_obegi[rd_adres] <= rs1 + genisletilmis;
                end else if(buyruk_tipi == 4'b0110) begin
                    //sw
                    ps_r <= ps_keep;
                    yazma_denetimi <= 0;
                end else if(buyruk_tipi == 4'b0111) begin
                    //lw
                    ps_r <= ps_keep; 
                    yazmac_obegi[rd_adres] <= bellek_verisi;
                end else if(buyruk_tipi == 4'b1000) begin
                    //beq
                    if(dallan) begin
                        ps_r <= ps_r + genisletilmis;
                    end
                end else if(buyruk_tipi == 4'b1001) begin
                    //jalr
                    ps_r <= rs1 + genisletilmis;
                    yazmac_obegi[rd_adres] <= ps_r + 4;
                end else if(buyruk_tipi == 4'b1010) begin
                    //jal
                    ps_r <= ps_r + genisletilmis;
                    yazmac_obegi[rd_adres] <= ps_r + 4;
                end else if(buyruk_tipi == 4'b1011) begin
                    //auipc
                    yazmac_obegi[rd_adres] <= ps_r + genisletilmis;
                end else if(buyruk_tipi == 4'b1100) begin
                    //lui
                    yazmac_obegi[rd_adres] <= genisletilmis;
                end else if(buyruk_tipi == 4'b1110) begin
                    ps_r <= ps_keep;
                end         
                simdiki_asama_r <= 0;
            end // end simdiki asama
         end else begin
            if(buyruk_tipi == 4'b1101) begin
                //ks  
                rs1_adres <= rs1_adres + 1;
                if(yazmac_obegi[rs1_adres + 1] > yazmac_obegi[rd_adres]) begin
                    rd_adres <= rd_adres + 1;
                    bigger <= 1;
                end else begin
                    bigger <= 0;
                end
                length <= length - 1;
            end else if(buyruk_tipi == 4'b1110) begin
                //ds
                yazma_denetimi <= 1;
                //alttaki atama deðeri rs1_adresini 1 arttýracaðýndan burada 1 eksik halini gönderiyorum.
                veri <= yazmac_obegi[rs1_adres - 1];
                ps_r <= ps_r + 4;
                rs1_adres <= rs1_adres + 1;
                length <= length - 1;
            end
         end //end ilerle_cmb    
    end // rst 
end // always

assign bellek_adres = ps_r;
assign bellek_yaz_veri = veri;
assign bellek_yaz = yazma_denetimi;

endmodule
