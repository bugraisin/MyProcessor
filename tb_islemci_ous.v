`timescale 1ns / 1ps

module tb_islemci_ous ();

   localparam BELLEK_ADRES = 32'h8000_0000;
   localparam ADRES_BIT = 32;
   localparam VERI_BIT = 32;

   reg clk_r;
   reg rst_r;

   wire [ADRES_BIT-1:0] islemci_bellek_adres;
   wire [VERI_BIT-1:0] islemci_bellek_oku_veri;
   wire [VERI_BIT-1:0] islemci_bellek_yaz_veri;
   wire islemci_bellek_yaz;

   anabellek anabellek (
       .clk(clk_r),
       .adres(islemci_bellek_adres),
       .oku_veri(islemci_bellek_oku_veri),
       .yaz_veri(islemci_bellek_yaz_veri),
       .yaz_gecerli(islemci_bellek_yaz)
   );

   islemci_ous islemci_ous (
       .clk(clk_r),
       .rst(rst_r),
       .bellek_adres(islemci_bellek_adres),
       .bellek_oku_veri(islemci_bellek_oku_veri),
       .bellek_yaz_veri(islemci_bellek_yaz_veri),
       .bellek_yaz(islemci_bellek_yaz)
   );

   always begin
      clk_r = 1'b0;
      #5;
      clk_r = 1'b1;
      #5;
   end

   localparam MAX_CYCLES = 100;
   integer stall_ctr;
   integer reg_num;
   integer start_reg;
   integer write_reg;
   reg [VERI_BIT-1:0] conf[0:7];
   reg [VERI_BIT-1:0] ks[0:3];
   initial begin
      //$dumpfile("tb_islemci_ous.vcd");
      //$dumpvars(0, tb_islemci_ous);
      //$dumpvars(0, islemci_ous);
      stall_ctr = 0;
      rst_r = 1'b1;

      @(posedge clk_r);
      // BUYRUKLAR 
      bellek_yaz('h8000_0000, 32'h00500293);  // addi x5, x0, 5 
      conf[0] = 5;
      ks[0]   = 5;
      bellek_yaz('h8000_0004, 32'h00a00313);  // addi x6, x0, 10
      conf[1] = 10;
      ks[1]   = 10;
      bellek_yaz('h8000_0008, 32'h00f00393);  // addi x7, x0, 15
      conf[2] = 15;
      ks[2]   = 15;
      bellek_yaz('h8000_000c, 32'h00c00413);  // addi x8, x0, 12
      conf[3] = 12;
      bellek_yaz('h8000_0010, 32'h00b00493);  // addi x9, x0, 11
      conf[4] = 11;
      bellek_yaz('h8000_0014, 32'h01900513);  // addi x10, x0, 25
      conf[5] = 25;
      ks[3]   = 25;
      bellek_yaz('h8000_0018, 32'h00a00593);  // addi x11, x0, 10
      conf[6] = 10;
      bellek_yaz('h8000_001c, 32'h01500613);  // addi x12, x0, 21
      conf[7] = 21;
      bellek_yaz('h8000_0020, {7'd0, 5'd7, 5'd5, 3'd1, 5'd16, 7'b1110011});  // ks   x16, x5, 7
      bellek_yaz('h8000_0024, {7'd0, 5'd5, 5'd5, 3'd2, 5'd13, 7'b1110011});  // ds   x13, x5, 7

      repeat (10) @(posedge clk_r);
      #2;  // 10 cevrim reset
      rst_r = 1'b0;

      islemci_ous.yazmac_obegi[13] = 32'h8000_0030;
      buyruk_kontrol(8);  // 8 buyruk yurut
      start_reg = 5;
      for (reg_num = 0; reg_num < 8; reg_num = reg_num + 1) begin
         if (yazmac_oku(reg_num + start_reg) !== conf[reg_num]) begin
            $display("[ERR] x%0d DEGER HATALI expected: %0d, actual: %0d", (reg_num + start_reg),
                     conf[reg_num], yazmac_oku(reg_num + start_reg));
         end
      end
      if (islemci_ous.ps_r !== 'h8000_0020) begin
         $display("[ERR] program sayaci 9. buyrugu gostermeli. PS: %h", islemci_ous.ps_r);
      end

      buyruk_kontrol(1);  // 1 buyruk yurut
      write_reg = 16;
      for (reg_num = 0; reg_num < 4; reg_num = reg_num + 1) begin
         if (yazmac_oku(reg_num + write_reg) !== ks[reg_num]) begin
            $display("[ERR] ks yazmac %0d expected %0d, actual %0d", (reg_num + write_reg),
                     ks[reg_num], yazmac_oku(reg_num + write_reg));
         end
      end
      buyruk_kontrol(1);  // 1 buyruk yurut
      start_reg = 5;
      $display("[TEST] Mem addr: 0x%h", yazmac_oku((bellek_oku(
                                                   'h8000_0024) & {(~(5'b0)), 7'b0}) >> 7));
      for (reg_num = 0; reg_num < 5; reg_num = reg_num + 1) begin
         if (yazmac_oku(reg_num + start_reg) !== bellek_oku(32'h8000_0030 + (4 * reg_num))) begin
            $display("[ERR] DS: x%0d yazmacinin degeri: %0d, Bellek adresi: 0x%h, degeri: %0d",
                     (reg_num + start_reg), yazmac_oku(reg_num + start_reg),
                     32'h8000_0030 + (4 * reg_num), bellek_oku(32'h8000_0030 + (4 * reg_num)));
         end
      end
      $finish;
   end
   // Islemcide buyruk_sayisi kadar buyruk yurutulmesini izler ve asama sirasini kontrol eder.
   task buyruk_kontrol(input [31:0] buyruk_sayisi);
      integer counter;
      begin
         for (counter = 0; counter < buyruk_sayisi; counter = counter + 1) begin
            while (!islemci_ous.ilerle_cmb) @(posedge clk_r) #2;
            asama_kontrol(islemci_ous.GETIR);
            @(posedge clk_r) #2;
            while (!islemci_ous.ilerle_cmb) @(posedge clk_r) #2;
            asama_kontrol(islemci_ous.COZYAZMACOKU);
            @(posedge clk_r) #2;
            while (!islemci_ous.ilerle_cmb) @(posedge clk_r) #2;
            asama_kontrol(islemci_ous.YURUTGERIYAZ);
            @(posedge clk_r) #2;
         end
      end
   endtask

   task asama_kontrol(input [1:0] beklenen);
      begin
         if (islemci_ous.simdiki_asama_r !== beklenen) begin
            $display("[ERR] YANLIS ASAMA expected: %0x actual: %0x", beklenen,
                     islemci_ous.simdiki_asama_r);
         end
      end
   endtask

   task bellek_yaz(input [ADRES_BIT-1:0] adres, input [VERI_BIT-1:0] veri);
      begin
         anabellek.bellek[adres_satir_idx(adres)] = veri;
      end
   endtask

   function [VERI_BIT-1:0] bellek_oku(input [ADRES_BIT-1:0] adres);
      begin
         bellek_oku = anabellek.bellek[adres_satir_idx(adres)];
      end
   endfunction

   function [VERI_BIT-1:0] yazmac_oku(input integer yazmac_idx);
      begin
         yazmac_oku = islemci_ous.yazmac_obegi[yazmac_idx];
      end
   endfunction

   // Verilen adresi bellek satir indisine donusturur.
   function integer adres_satir_idx(input [ADRES_BIT-1:0] adres);
      begin
         adres_satir_idx = (adres - BELLEK_ADRES) >> $clog2(VERI_BIT / 8);
      end
   endfunction

endmodule
