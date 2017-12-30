/***********************************************************************
  $FILENAME    : eth_intrfc_top_pkg.svh

  $TITLE       : Package definition

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This package include some common code to be shared 
                 across multiple modules in the verification system. 

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


package eth_intrfc_top_pkg;

 parameter [47:0] DEVICE_MAC         = 48'h001AA0D5CF0F;
 parameter [31:0] DEVICE_IP          = 32'h8d59342B;     
 parameter [31:0] DEST_IP            = 32'h0a0105ce;     
 parameter [15:0] DEST_TCPCLNT_PORT  = 16'hBC14;
 parameter [15:0] SRC_TCPCLNT_PORT   = 16'hDFCC;         // Source TCP Client Port
 parameter [15:0] DEVICE_TCP_PORT    = 16'hE28C;
 parameter [15:0] DEVICE_TCP_PAYLOAD = 16'h0020;         // 32-byte payload
 parameter [15:0] DEVICE_UDP_PORT    = 16'hbed0;         // 48848			
 parameter [15:0] DEST_UDP_PORT      = 16'h1b3b;
	
  
    
  // ============================================================= 
  // ARP REQ
  // =============================================================
  //No.     Time        Source                Destination           Protocol Length Info
  //      1 0.000000    Dell_d4:b2:44         Broadcast             ARP      42     Who has 141.89.52.43?  Tell 141.89.52.200

  //Ethernet II, Src: Dell_4d:29:05 (00:1c:23:4d:29:05), Dst: Broadcast (ff:ff:ff:ff:ff:ff)
  //    Destination: Broadcast (ff:ff:ff:ff:ff:ff)
  //        Address: Broadcast (ff:ff:ff:ff:ff:ff)
  //        .... ...1 .... .... .... .... = IG bit: Group address (multicast/broadcast)
  //        .... ..1. .... .... .... .... = LG bit: Locally administered address (this is NOT the factory default)
  //    Source: Dell_4d:29:05 (00:1c:23:4d:29:05)
  //        Address: Dell_4d:29:05 (00:1c:23:4d:29:05)
  //        .... ...0 .... .... .... .... = IG bit: Individual address (unicast)
  //        .... ..0. .... .... .... .... = LG bit: Globally unique address (factory default)
  //    Type: ARP (0x0806)
  //Address Resolution Protocol (request)
  //    Hardware type: Ethernet (1)
  //    Protocol type: IP (0x0800)
  //    Hardware size: 6
  //    Protocol size: 4
  //    Opcode: request (1)
  //    [Is gratuitous: False]
  //    Sender MAC address: Dell_d4:b2:44 (84:8f:69:d4:b2:44)
  //    Sender IP address: 141.89.52.200 (141.89.52.200)
  //    Target MAC address: 00:00:00_00:00:00 (00:00:00:00:00:00)
  //    Target IP address: 141.89.52.43 (141.89.52.43)

  
  
  // ARP: Who has 141.89.52.43? Tell 141.89.52.200
  const bit [7:0] ARP_CLIENT_REQ [] = '{  
    // Ethernet II
    // Destination: Broadcast (ff:ff:ff:ff:ff:ff)
    8'hFF,
    8'hFF,
    8'hFF,
    8'hFF,

    // Destination: Broadcast (ff:ff:ff:ff:ff:ff)
    // Source: akzare.notebook (00:1c:23:4d:29:05)
    8'hFF,
    8'hFF,
    8'h00,
    8'h1C,

    // Source: akzare.notebook (00:1c:23:4d:29:05)
    8'h23,
    8'h4D,
    8'h29,
    8'h05,

    // Type: ARP (0x0806)
    // Address Resolution Protocol (request)
    // Hardware Type: Ethernet (0x0001)
    8'h08,
    8'h06,
    8'h00,
    8'h01,

    // Protocol Type: IP (0x0800)
    // Hardware Size: 6
    // Protocol Size: 4
    8'h08,
    8'h00,
    8'h06,
    8'h04,

    // Opcode: request (0x0001)
    // Sender MAC Address: akzare.notebook (00:1c:23:4d:29:05)
    8'h00,
    8'h01,
    8'h00,
    8'h1C,

    // Sender MAC Address: akzare.notebook (00:1c:23:4d:29:05)
    8'h23,
    8'h4D,
    8'h29,
    8'h05,

    // Sender IP Address: akzare.notebook (141.89.52.200)
    8'h8D,
    8'h59,
    8'h34,
    8'hC8,

    // Target MAC Address: (00:00:00:00:00:00)
    8'h00,
    8'h00,
    8'h00,
    8'h00,

    // Target MAC Address: (00:00:00:00:00:00)
    // Target IP Address: (141.89.52.43)
    8'h00,
    8'h00,
    8'h8D,
    8'h59,

    // Target IP Address: (141.89.52.43)
    8'h34,
    8'h2B,
    8'h00,
    8'h00    
  };


  // ============================================================= 
  // ICMP (ping) REQ
  // ============================================================= 
  //No.     Time        Source                Destination           Protocol Length Info
  //      3 0.000612    141.89.52.200         141.89.52.43         ICMP     98     Echo (ping) request  id=0xeb67, seq=1/256, ttl=64

  //Frame 3: 98 bytes on wire (784 bits), 98 bytes captured (784 bits)
  //Ethernet II, Src: Dell_4d:b2:44 (84:8f:69:d4:b2:44), Dst: 02:00:00:00:00:00 (02:00:00:00:00:00)
  //    Destination: 02:00:00:00:00:00 (02:00:00:00:00:00)
  //        Address: 02:00:00:00:00:00 (02:00:00:00:00:00)
  //        .... ...0 .... .... .... .... = IG bit: Individual address (unicast)
  //        .... ..1. .... .... .... .... = LG bit: Locally administered address (this is NOT the factory default)
  //    Source: Dell_4d:b2:44 (84:8f:69:d4:b2:44)
  //        Address: Dell_4d:b2:44 (84:8f:69:d4:b2:44)
  //        .... ...0 .... .... .... .... = IG bit: Individual address (unicast)
  //        .... ..0. .... .... .... .... = LG bit: Globally unique address (factory default)
  //    Type: IP (0x0800)
  //Internet Protocol Version 4, Src: 141.89.52.200 (141.89.52.200), Dst: 141.89.52.43 (141.89.52.43)
  //    Version: 4
  //    Header length: 20 bytes
  //    Differentiated Services Field: 0x00 (DSCP 0x00: Default; ECN: 0x00: Not-ECT (Not ECN-Capable Transport))
  //        0000 00.. = Differentiated Services Codepoint: Default (0x00)
  //        .... ..00 = Explicit Congestion Notification: Not-ECT (Not ECN-Capable Transport) (0x00)
  //    Total Length: 84
  //    Identification: 0x0000 (0)
  //    Flags: 0x02 (Don't Fragment)
  //        0... .... = Reserved bit: Not set
  //        .1.. .... = Don't fragment: Set
  //        ..0. .... = More fragments: Not set
  //    Fragment offset: 0
  //    Time to live: 64
  //    Protocol: ICMP (1)
  //    Header checksum: 0xb6a5 [correct]
  //        [Good: True]
  //        [Bad: False]
  //    Source: 141.89.52.200 (141.89.52.200)
  //    Destination: 141.89.52.43 (141.89.52.43)
  //Internet Control Message Protocol
  //    Type: 8 (Echo (ping) request)
  //    Code: 0
  //    Checksum: 0x6e0a [correct]
  //    Identifier (BE): 60263 (0xeb67)
  //    Identifier (LE): 26603 (0x67eb)
  //    Sequence number (BE): 1 (0x0001)
  //    Sequence number (LE): 256 (0x0100)
  //    [Response In: 4]
  //    Data (56 bytes)
  //        Data: f21cf84abe210b0008090a0b0c0d0e0f1011121314151617...
  //        [Length: 56]

  // ICMP: Ping request
  const bit [7:0] ICMP_CLIENT_PING_REQ [] = '{
    // Ethernet II
    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F) 
	8'h00,
	8'h1a,
	8'ha0,
    8'hd5,

    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F)
    // Source: akzare.notebook (00:1c:23:4d:29:05)
	8'hcf,
	8'h0f,
	8'h00,
    8'h1c,

    // Source: akzare.notebook (00:1c:23:4d:29:05)
	8'h23,
	8'h4d,
	8'h29,
    8'h05,

    // Type: IP (0x0800)
    // Version : 4
    // Header Length: 20 bytes
    // Differentiated Service Field: 0x00 (DSCP: 0x00: Default; ECN: 0x00)
    //    0000 00.. = Diff Service CodePoint: Default (0x00)
    //    .... ..0. = ECN-Capable Transport (ECT): 0
    //    .... ...0 = ECN-CE: 0
	8'h08,
	8'h00,
	8'h45,
    8'h00,

    // Total Length: 84 (0x0054)
    // Identification: 0x0000
	8'h00,
	8'h54,
	8'h00,
    8'h00,

    // Flags: 0x04 (Don't Fragment)
    //     0... = Reserved bit : Not Set
    //     .1.. = Don't fragment : Set
    //     ..0. = More fragments : Not Set
    // Fragment offset: 0
    // Time To Live: 64
    // Protocol: ICMP (0x01)
	8'h40,
	8'h00,
	8'h40,
    8'h01,

    // Header Checksum: 0xb6a5
    // Source: (141.89.52.200)
	8'hb7,
	8'h03,
	8'h8d,
    8'h59,

    // Source: (141.89.52.200)
    // Destination: (141.89.52.43)
	8'h34,
	8'hc8,
	8'h8d,
    8'h59,

    // Destination: (141.89.52.43)
    // Internet Control Message Protocol
    // Type: 8 (Echo Ping Request)
    // Code: 0
	8'h34,
	8'h2b,
	8'h08,
    8'h00,

    // Checksum: 0x6e0a
    // Identifier: 0xeb67
	8'h6e,
	8'h0a,
	8'heb,
    8'h67,

    // Sequence number: 1(0x0001)
    // Data: F2 1C (56 bytes)
	8'h00,
	8'h01,
	8'hf2,
    8'h1c,

    // Data: F8 4A BE 21 (56 bytes)
	8'hf8,
	8'h4a,
	8'hbe,
    8'h21,

    // Data: 0B 00 08 09 (56 bytes)
	8'h0b,
	8'h00,
	8'h08,
    8'h09,

    // Data: 0A 0B 0C 0D (56 bytes)
	8'h0a,
	8'h0b,
	8'h0c,
    8'h0d,

    // Data: 0E 0F 10 11 (56 bytes)
	8'h0e,
	8'h0f,
	8'h10,
    8'h11,

    // Data: 12 13 14 15 (56 bytes)
	8'h12,
	8'h13,
	8'h14,
    8'h15,

    // Data: 16 17 18 19 (56 bytes)
	8'h16,
	8'h17,
	8'h18,
    8'h19,

    // Data: 1A 1B 1C 1D (56 bytes)
	8'h1a,
	8'h1b,
	8'h1c,
    8'h1d,

    // Data: 1E 1F 20 21 (56 bytes)
	8'h1e,
	8'h1f,
	8'h20,
    8'h21,

    // Data: 22 23 24 25 (56 bytes)
	8'h22,
	8'h23,
	8'h24,
    8'h25,

    // Data: 26 27 28 29 (56 bytes)
	8'h26,
	8'h27,
	8'h28,
    8'h29,

    // Data: 2A 2B 2C 2D (56 bytes)
	8'h2a,
	8'h2b,
	8'h2c,
    8'h2d,

    // Data: 2E 2F 30 31 (56 bytes)
	8'h2e,
	8'h2f,
	8'h30,
    8'h31,

    // Data: 32 33 34 35 (56 bytes)
	8'h32,
	8'h33,
	8'h34,
    8'h35,

    // Data: 36 37 (56 bytes)
	8'h36,
	8'h37,
	8'h00,
	8'h00
  };

  // Client TCP
  // ============================================================= 
  // TCP: Client SYN
  // ============================================================= 
  const bit [7:0] TCP_CLIENT_SYN [] = '{

    // Ethernet II
    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F) 
    8'h00,
	8'h1a,
	8'ha0,
    8'hd5,

    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F)
    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'hcf,
	8'h0f,
	8'h00,
    8'h1c,

    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'h23,
	8'h4d,
	8'h29,
    8'h05,

    // Type: IP (0x0800)
    // Version : 4
    // Header Length: 20 bytes
    // Differentiated Service Field: 0x00 (DSCP: 0x00: Default; ECN: 0x00)
    //    0000 00.. = Diff Service CodePoint: Default (0x00)
    //    .... ..0. = ECN-Capable Transport (ECT): 0
    //    .... ...0 = ECN-CE: 0
    8'h08,
	8'h00,
	8'h45,
    8'h00,

    // Total Length: 60 (0x003C)
    // Identification: 0x78AD
    8'h00,
	8'h3C,
	8'h78,
    8'hAD,

    // Flags: 0x04 (Don't Fragment)
    //     0... = Reserved bit : Not Set
    //     .1.. = Don't fragment : Set
    //     ..0. = More fragments : Not Set
    // Fragment offset: 0
    // Time To Live: 64
    // Protocol: TCP (0x06)
    8'h40,
	8'h00,
	8'h40,
    8'h06,

    // Header Checksum: 0x3e69
    // Source: (141.89.52.200)
    8'h3e,
	8'h69,
	8'h8d,
    8'h59,

    // Source: (141.89.52.200)
    // Destination: (141.89.52.43)
    8'h34,
	8'hc8,
	8'h8d,
    8'h59,

    // Destination: (141.89.52.43)
    // TCP starts
    // Source Port: 0xDFCC (57292)
    8'h34,
	8'h2b,
	8'hDF,
    8'hCC,

    // Destination Port: 0xE28C (57996)
    // Sequence number: 0x8A206422
    8'he2,
	8'h8c,
	8'h8a,
    8'h20,

    // Sequence number: 0x8A206422
    // Acknowledge number: 0x00000000
    8'h64,
	8'h22,
	8'h00,
    8'h00,

    // Acknowledge number: 0x00000000
    // Header length: 0xA0 (40 bytes)
    // Flags: 0x02 (SYN)
    //    0... .... = Congestion Window Reduced (CWR): Not Set
    //    .0.. .... = ECN-Echo : Not Set
    //    ..0. .... = Urgent : Not Set
    //    ...0 .... = Acknowledgment : Not Set
    //    .... 0... = Push : Not Set
    //    .... .0.. = Reset : Not Set
    //    .... ..1. = Syn : Set
    //    .... ...0 = Fin : Not Set
    8'h00,
	8'h00,
	8'ha0,
    8'h02,

    // Window Size: 0x16D0 (multiply by 1=5840)
    // Checksum: 0xE05B (correct)
    8'h16,
	8'hd0,
	8'he0,
    8'h5b,

    // Urgent pointer: 0x0000
    // Options: (20 bytes)
    //         Maximum Segment Size: 0x020405b4 (Kind=2 Length=4 Size=1460 bytes)
    8'h00,
	8'h00,
	8'h02,
    8'h04,

    //         Maximum Segment Size: 0x020405b4 (Kind=2 Length=4 Size=1460 bytes)
    //         SACK permitted: 0x0402 (Kind=4 Length=2)
	8'h05,
	8'hb4,
	8'h04,
    8'h02,

    //         Timestamps: 0x080a00041C8F00000000 TSval 269455, TSecr 0 (Kind=8 Length=10 TSval TSecr)
    8'h08,
	8'h0a,
	8'h00,
    8'h04,

    //         Timestamps: 0x080a00041C8F00000000 TSval 269455, TSecr 0 (Kind=8 Length=10 TSval TSecr)
    8'h1c,
	8'h8f,
	8'h00,
    8'h00,

    //         Timestamps: 0x080a00041C8F00000000 TSval 269455, TSecr 0 (Kind=8 Length=10 TSval TSecr)
    //         NOP: 0x01
    //         Window scale: 0x030306 -> 6 (multiply by 64) (Kind=3 Length=3 shift_count)
    8'h00,
	8'h00,
	8'h01,
    8'h03,

    //         Window scale: 0x030306 -> 6 (multiply by 64) (Kind=3 Length=3 shift_count)
    8'h03,
	8'h06,
	8'h00,
	8'h00
  };


  // ============================================================= 
  // TCP: Client SYNC ACK ACK 
  // ============================================================= 
  const bit [7:0] TCP_CLIENT_SYNC_ACK_ACK [] = '{
    // Ethernet II
    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F) 
    8'h00,
	8'h1a,
	8'ha0,
    8'hd5,

    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F)
    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'hcf,
	8'h0f,
	8'h00,
    8'h1c,

    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'h23,
	8'h4d,
	8'h29,
    8'h05,

    // Type: IP (0x0800)
    // Version : 4
    // Header Length: 20 bytes
    // Differentiated Service Field: 0x00 (DSCP: 0x00: Default; ECN: 0x00)
    //    0000 00.. = Diff Service CodePoint: Default (0x00)
    //    .... ..0. = ECN-Capable Transport (ECT): 0
    //    .... ...0 = ECN-CE: 0
    8'h08,
	8'h00,
	8'h45,
    8'h00,

    // Total Length: 52 (0x0034)
    // Identification: 0x78AE
    8'h00,
	8'h34,
	8'h78,
    8'hAE,

    // Flags: 0x04 (Don't Fragment)
    //     0... = Reserved bit : Not Set
    //     .1.. = Don't fragment : Set
    //     ..0. = More fragments : Not Set
    // Fragment offset: 0
    // Time To Live: 64
    // Protocol: TCP (0x06)
    8'h40,
	8'h00,
	8'h40,
    8'h06,

    // Header Checksum: 0x3e70
    // Source: (141.89.52.200)
    8'h3e,
	8'h70,
	8'h8d,
    8'h59,

    // Source: (141.89.52.200)
    // Destination: (141.89.52.43)
    8'h34,
	8'hc8,
	8'h8d,
    8'h59,

    // Destination: (141.89.52.43)
    // TCP starts
    // Source Port: 0xDFCE (57292)
    8'h34,
	8'h2b,
	8'hDF,
    8'hCC,

    // Destination Port: 0xE28C (57996)
    // Sequence number: 0x8A206423
    8'he2,
	8'h8c,
	8'h8a,
    8'h20,

    // Sequence number: 0x8A206423
    // Acknowledge number: 0xC4B34410
    8'h64,
	8'h23,
	8'hc4,
    8'hb3,

    // Acknowledge number: 0xC4B34410
    // Header length: 0x80 (32 bytes)
    // Flags: 0x10 (ACK)
    //    0... .... = Congestion Window Reduced (CWR): Not Set
    //    .0.. .... = ECN-Echo : Not Set
    //    ..0. .... = Urgent : Not Set
    //    ...0 .... = Acknowledgment : Not Set
    //    .... 0... = Push : Not Set
    //    .... .0.. = Reset : Not Set
    //    .... ..1. = Syn : Set
    //    .... ...0 = Fin : Not Set
    8'h44,
	8'h10,
	8'h80,
    8'h10,

    // Window Size: 0x005C (multiply by 64=5888)
    // Checksum: 0xBD94 (correct)
    8'h00,
	8'h5c,
	8'hbd,
    8'h94,

    // Urgent pointer: 0x0000
    // Options: (20 bytes)
    //         NOP: 0x01
    //         NOP: 0x01
    8'h00,
	8'h00,
	8'h01,
    8'h01,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h08,
	8'h0a,
	8'h00,
    8'h04,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h1c,
	8'h8f,
	8'h03,
    8'hbb,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h5b,
	8'h77,
	8'h00,
    8'h00
  };


  // ============================================================= 
  // TCP: Client GIOP 1.2 Request
  // ============================================================= 
  const bit [7:0] TCP_CLIENT_GIOP_REQ [] = '{
    // Ethernet II
    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F) 
    8'h00,
	8'h1a,
	8'ha0,
    8'hd5,

    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F)
    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'hcf,
	8'h0f,
	8'h00,
    8'h1c,

    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'h23,
	8'h4d,
	8'h29,
    8'h05,

    // Type: IP (0x0800)
    // Version : 4
    // Header Length: 20 bytes
    // Differentiated Service Field: 0x00 (DSCP: 0x00: Default; ECN: 0x00)
    //    0000 00.. = Diff Service CodePoint: Default (0x00)
    //    .... ..0. = ECN-Capable Transport (ECT): 0
    //    .... ...0 = ECN-CE: 0
    8'h08,
	8'h00,
	8'h45,
    8'h00,

    // Total Length: 152 (0x0098)
    // Identification: 0x78AF
    8'h00,
	8'h98,
	8'h78,
    8'hAF,

    // Flags: 0x04 (Don't Fragment)
    //     0... = Reserved bit : Not Set
    //     .1.. = Don't fragment : Set
    //     ..0. = More fragments : Not Set
    // Fragment offset: 0
    // Time To Live: 64
    // Protocol: TCP (0x06)
    8'h40,
	8'h00,
	8'h40,
    8'h06,

    // Header Checksum: 0x3e0B
    // Source: (141.89.52.200)
    8'h3e,
	8'h0b,
	8'h8d,
    8'h59,

    // Source: (141.89.52.200)
    // Destination: (141.89.52.43)
    8'h34,
	8'hc8,
	8'h8d,
    8'h59,

    // Destination: (141.89.52.43)
    // TCP starts
    // Source Port: 0xDFCC (57292)
    8'h34,
	8'h2b,
	8'hDF,
    8'hCC,

    // Destination Port: 0xE28C (57996)
    // Sequence number: 0x8A206423
    8'he2,
	8'h8c,
	8'h8a,
    8'h20,

    // Sequence number: 0x8A206423
    // Acknowledge number: 0xC4B34410
    8'h64,
	8'h23,
	8'hc4,
    8'hb3,

    // Acknowledge number: 0xC4B34410
    // Header length: 0x80 (32 bytes)
    // Flags: 0x18 (PSH ACK)
    //    0... .... = Congestion Window Reduced (CWR): Not Set
    //    .0.. .... = ECN-Echo : Not Set
    //    ..0. .... = Urgent : Not Set
    //    ...0 .... = Acknowledgment : Not Set
    //    .... 0... = Push : Not Set
    //    .... .0.. = Reset : Not Set
    //    .... ..1. = Syn : Set
    //    .... ...0 = Fin : Not Set
    8'h44,
	8'h10,
	8'h80,
    8'h18,

    // Window Size: 0x005C (multiply by 64=5888)
    // Checksum: 0x8430 (incorrect, should be 0x61F4, maybe caused by TCP checksum offload!)
    8'h00,
	8'h5c,
	8'h8A,
    8'hc3,

    // Urgent pointer: 0x0000
    // Options: (20 bytes)
    //         NOP: 0x01
    //         NOP: 0x01
    8'h00,
	8'h00,
	8'h01,
    8'h01,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h08,
	8'h0a,
	8'h00,
    8'h04,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h1c,
	8'h8f,
	8'h03,
    8'hbb,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    // General Inter-ORB Protocol start
    // Magic number: GIOP (0x47494F50)
    8'h5b,
	8'h77,
	8'h47,
    8'h49,

    // Magic number: GIOP (0x47494F50)
    // Version: 1.2 (0x0102)
    8'h4f,
	8'h50,
	8'h01,
	8'h08,
    8'h02,

    // Flags: 0x01 (little-endian)
    // Message type: Request (0x00)
    // Message size: 88 (0x58000000)
    8'h01,
	8'h00,
	8'h58,
    8'h00,

    // Message size: 88 (0x58000000)
    // General Inter-ORB Protocol Request start
    // Request id: 1 (0x01000000)
    8'h00,
	8'h00,
	8'h01,
    8'h00,

    // Request id: 1 (0x01000000)
    // Response flags: SYNC_WITH_TARGET (0x03)
    // Reserved: (0x000000)
    8'h00,
	8'h00,
	8'h03,
    8'h00,

    // Reserved: (0x000000)
    // TargetAddress Discriminant: (0x0000)
    8'h00,
	8'h00,
	8'h00,
    8'h00,

    // ???: (0x0000)
    // KeyAddr: (object key length) 27 (0x1B000000)
    8'h00,
	8'h00,
	8'h1b,
    8'h00,

    // KeyAddr: (object key length) 27 (0x1B000000)
    // KeyAddr: (object key) (0x14010F0052535448A0134B56D60900000000000100000001000000)
    8'h00,
	8'h00,
	8'h14,
    8'h01,

    // KeyAddr: (object key) (0x14010F0052535448A0134B56D60900000000000100000001000000)
    8'h0f,
	8'h00,
	8'h52,
    8'h53,

    // KeyAddr: (object key) (0x14010F0052535448A0134B56D60900000000000100000001000000)
    8'h54,
	8'h48,
	8'ha0,
    8'h13,

    // KeyAddr: (object key) (0x14010F0052535448A0134B56D60900000000000100000001000000)
    8'h4b,
	8'h56,
	8'hd6,
    8'h09,

    // KeyAddr: (object key) (0x14010F0052535448A0134B56D60900000000000100000001000000)
    8'h00,
	8'h00,
	8'h00,
    8'h00,

    // KeyAddr: (object key) (0x14010F0052535448A0134B56D60900000000000100000001000000)
    8'h00,
	8'h01,
	8'h00,
    8'h00,

    // KeyAddr: (object key) (0x14010F0052535448A0134B56D60900000000000100000001000000)
    8'h00,
	8'h01,
	8'h00,
    8'h00,

    // KeyAddr: (object key) (0x14010F0052535448A0134B56D60900000000000100000001000000)
    // ???: 0x00
    // Operation length: 13 (0x0D000000)
    8'h00,
	8'h00,
	8'h0d,
    8'h00,

    // Operation length: 13 (0x0D000000)
    // Request operation: get_shortseq (0x6765745F73686F727473657100)
    8'h00,
	8'h00,
	8'h67,
    8'h65,

    // Request operation: get_shortseq (0x6765745F73686F727473657100)
    8'h74,
	8'h5f,
	8'h73,
    8'h68,

    // Request operation: get_shortseq (0x6765745F73686F727473657100)
    8'h6f,
	8'h72,
	8'h74,
    8'h73,

    // Request operation: get_shortseq (0x6765745F73686F727473657100)
    // ServiceContextList
    // ???: 0x000000
    8'h65,
	8'h71,
	8'h00,
    8'h00,

    // ???: 0x000000
    // Sequence Length: 1 (0x01000000)
    8'h00,
	8'h00,
	8'h01,
    8'h00,

    // Sequence Length: 1 (0x01000000)
    // (0x01000000) -->
    //          0000 0000 0000 0000 0000 0000 .... .... = VSCID: 0x00000000
    //          .... .... .... .... .... .... 0000 0001 = SCID: 0x00000001
    8'h00,
	8'h00,
	8'h01,
    8'h00,

    // (0x01000000) -->
    //          0000 0000 0000 0000 0000 0000 .... .... = VSCID: 0x00000000
    //          .... .... .... .... .... .... 0000 0001 = SCID: 0x00000001
    // Service Context ID: CodeSets
    // CodeSets
    // ???: 0x0C00000001000000
    8'h00,
	8'h00,
	8'h0c,
    8'h00,

    // ???: 0x0C00000001000000
    8'h00,
	8'h00,
	8'h01,
    8'h00,

    // ???: 0x0C00000001000000
    //    char_data: 0x00010001 ISO_8859_1
    8'h00,
	8'h00,
	8'h01,
    8'h00,

    //    char_data: 0x00010001 ISO_8859_1
    //    char_data: 0x00010109 ISO_UTF_16
    8'h01,
	8'h00,
	8'h09,
    8'h01,

    //    char_data: 0x00010109 ISO_UTF_16
    8'h01,
	8'h00,
	8'h00,
    8'h00
  };


  // ============================================================= 
  // TCP: Client GIOP DATA ACK
  // ============================================================= 
  const bit [7:0] TCP_CLIENT_GIOP_DATA_ACK [] = '{
    // Ethernet II
    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F) 
    8'h00,
	8'h1a,
	8'ha0,
    8'hd5,

    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F)
    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'hcf,
	8'h0f,
	8'h00,
    8'h1c,

    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'h23,
	8'h4d,
	8'h29,
    8'h05,

    // Type: IP (0x0800)
    // Version : 4
    // Header Length: 20 bytes
    // Differentiated Service Field: 0x00 (DSCP: 0x00: Default; ECN: 0x00)
    //    0000 00.. = Diff Service CodePoint: Default (0x00)
    //    .... ..0. = ECN-Capable Transport (ECT): 0
    //    .... ...0 = ECN-CE: 0
    8'h08,
	8'h00,
	8'h45,
    8'h00,

    // Total Length: 52 (0x0034)
    // Identification: 0x78B0
    8'h00,
	8'h34,
	8'h78,
    8'hB0,

    // Flags: 0x04 (Don't Fragment)
    //     0... = Reserved bit : Not Set
    //     .1.. = Don't fragment : Set
    //     ..0. = More fragments : Not Set
    // Fragment offset: 0
    // Time To Live: 64
    // Protocol: TCP (0x06)
    8'h40,
	8'h00,
	8'h40,
    8'h06,

    // Header Checksum: 0x3e6E
    // Source: (141.89.52.200)
    8'h3e,
	8'h6e,
	8'h8d,
    8'h59,

    // Source: (141.89.52.200)
    // Destination: (141.89.52.43)
    8'h34,
	8'hc8,
	8'h8d,
    8'h59,

    // Destination: (141.89.52.43)
    // TCP starts
    // Source Port: 0xDFCE (57292)
    8'h34,
	8'h2b,
	8'hDF,
    8'hCC,

    // Destination Port: 0xE28C (57996)
    // Sequence number: 0x8A206487
    8'he2,
	8'h8c,
	8'h8a,
    8'h20,

    // Sequence number: 0x8A206487
    // Acknowledge number: 0xC4B34814
    8'h64,
	8'h87,
	8'hc4,
    8'hb3,

    // Acknowledge number: 0xC4B34814
    // Header length: 0x80 (32 bytes)
    // Flags: 0x10 (ACK)
    //    0... .... = Congestion Window Reduced (CWR): Not Set
    //    .0.. .... = ECN-Echo : Not Set
    //    ..0. .... = Urgent : Not Set
    //    ...0 .... = Acknowledgment : Not Set
    //    .... 0... = Push : Not Set
    //    .... .0.. = Reset : Not Set
    //    .... ..1. = Syn : Set
    //    .... ...0 = Fin : Not Set
    8'h48,
	8'h14,
	8'h80,
    8'h10,

    // Window Size: 0x007C (multiply by 64=5888)
    // Checksum: 0xB90C (correct)
    8'h00,
	8'h7c,
	8'hb9,
    8'h0c,

    // Urgent pointer: 0x0000
    // Options: (20 bytes)
    //         NOP: 0x01
    //         NOP: 0x01
    8'h00,
	8'h00,
	8'h01,
    8'h01,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h08,
	8'h0a,
	8'h00,
    8'h04,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h1c,
	8'h8f,
	8'h03,
    8'hbb,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h5b,
	8'h77,
	8'h00,
    8'h00
  };


  // ============================================================= 
  // TCP: Client FIN ACK
  // ============================================================= 
  const bit [7:0] TCP_CLIENT_FIN_ACK [] = '{
    // Ethernet II
    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F) 
    8'h00,
	8'h1a,
	8'ha0,
    8'hd5,

    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F)
    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'hcf,
	8'h0f,
	8'h00,
    8'h1c,

    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'h23,
	8'h4d,
	8'h29,
    8'h05,

    // Type: IP (0x0800)
    // Version : 4
    // Header Length: 20 bytes
    // Differentiated Service Field: 0x00 (DSCP: 0x00: Default; ECN: 0x00)
    //    0000 00.. = Diff Service CodePoint: Default (0x00)
    //    .... ..0. = ECN-Capable Transport (ECT): 0
    //    .... ...0 = ECN-CE: 0
    8'h08,
	8'h00,
	8'h45,
    8'h00,

    // Total Length: 52 (0x0034)
    // Identification: 0x78B1
    8'h00,
	8'h34,
	8'h78,
    8'hB1,

    // Flags: 0x04 (Don't Fragment)
    //     0... = Reserved bit : Not Set
    //     .1.. = Don't fragment : Set
    //     ..0. = More fragments : Not Set
    // Fragment offset: 0
    // Time To Live: 64
    // Protocol: TCP (0x06)
    8'h40,
	8'h00,
	8'h40,
    8'h06,

    // Header Checksum: 0x3e6D
    // Source: (141.89.52.200)
    8'h3e,
	8'h6d,
	8'h8d,
    8'h59,

    // Source: (141.89.52.200)
    // Destination: (141.89.52.43)
    8'h34,
	8'hc8,
	8'h8d,
    8'h59,

    // Destination: (141.89.52.43)
    // TCP starts
    // Source Port: 0xDFCE (57292)
    8'h34,
	8'h2b,
	8'hDF,
    8'hCC,

    // Destination Port: 0xE28C (57996)
    // Sequence number: 0x8A206487
    8'he2,
	8'h8c,
	8'h8a,
    8'h20,

    // Sequence number: 0x8A206487
    // Acknowledge number: 0xC4B34814
    8'h64,
	8'h87,
	8'hc4,
    8'hb3,

    // Acknowledge number: 0xC4B34814
    // Header length: 0x80 (32 bytes)
    // Flags: 0x11 (FIN ACK)
    //    0... .... = Congestion Window Reduced (CWR): Not Set
    //    .0.. .... = ECN-Echo : Not Set
    //    ..0. .... = Urgent : Not Set
    //    ...0 .... = Acknowledgment : Not Set
    //    .... 0... = Push : Not Set
    //    .... .0.. = Reset : Not Set
    //    .... ..1. = Syn : Set
    //    .... ...0 = Fin : Not Set
    8'h48,
	8'h14,
	8'h80,
    8'h11,

    // Window Size: 0x007C (multiply by 64=5888)
    // Checksum: 0xB8F6 (correct)
    8'h00,
	8'h7c,
	8'hb8,
    8'hf6,

    // Urgent pointer: 0x0000
    // Options: (20 bytes)
    //         NOP: 0x01
    //         NOP: 0x01
    8'h00,
	8'h00,
	8'h01,
    8'h01,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h08,
	8'h0a,
	8'h00,
    8'h04,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h1c,
	8'ha4,
	8'h03,
    8'hbb,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h5b,
	8'h77,
	8'h00,
    8'h00
  };


  // ============================================================= 
  // TCP: Client LAST ACK
  // ============================================================= 
  const bit [7:0] TCP_CLIENT_ACK_LAST [] = '{
    // Ethernet II
    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F) 
    8'h00,
	8'h1a,
	8'ha0,
    8'hd5,

    // Destination: 141.89.52.43 (00:1A:A0:D5:CF:0F)
    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'hcf,
	8'h0f,
	8'h00,
    8'h1c,

    // Source: 141.89.52.200 (00:1c:23:4d:29:05)
    8'h23,
	8'h4d,
	8'h29,
    8'h05,

    // Type: IP (0x0800)
    // Version : 4
    // Header Length: 20 bytes
    // Differentiated Service Field: 0x00 (DSCP: 0x00: Default; ECN: 0x00)
    //    0000 00.. = Diff Service CodePoint: Default (0x00)
    //    .... ..0. = ECN-Capable Transport (ECT): 0
    //    .... ...0 = ECN-CE: 0
    8'h08,
	8'h00,
	8'h45,
    8'h00,

    // Total Length: 52 (0x0034)
    // Identification: 0x78B2
    8'h00,
	8'h34,
	8'h78,
    8'hB2,

    // Flags: 0x04 (Don't Fragment)
    //     0... = Reserved bit : Not Set
    //     .1.. = Don't fragment : Set
    //     ..0. = More fragments : Not Set
    // Fragment offset: 0
    // Time To Live: 64
    // Protocol: TCP (0x06)
    8'h40,
	8'h00,
	8'h40,
    8'h06,

    // Header Checksum: 0x3e6C
    // Source: (141.89.52.200)
    8'h3e,
	8'h6C,
	8'h8d,
    8'h59,

    // Source: (141.89.52.200)
    // Destination: (141.89.52.43)
    8'h34,
	8'hc8,
	8'h8d,
    8'h59,

    // Destination: (141.89.52.43)
    // TCP starts
    // Source Port: 0xDFCE (57292)
    8'h34,
	8'h2b,
	8'hDF,
    8'hCC,

    // Destination Port: 0xE28C (57996)
    // Sequence number: 0x8A206487
    8'he2,
	8'h8c,
	8'h8a,
    8'h20,

    // Sequence number: 0x8A206488
    // Acknowledge number: 0xC4B34815
    8'h64,
	8'h88,
	8'hc4,
    8'hb3,

    // Acknowledge number: 0xC4B34815
    // Header length: 0x80 (32 bytes)
    // Flags: 0x11 (FIN)
    //    0... .... = Congestion Window Reduced (CWR): Not Set
    //    .0.. .... = ECN-Echo : Not Set
    //    ..0. .... = Urgent : Not Set
    //    ...0 .... = Acknowledgment : Not Set
    //    .... 0... = Push : Not Set
    //    .... .0.. = Reset : Not Set
    //    .... ..1. = Syn : Set
    //    .... ...0 = Fin : Not Set
    8'h48,
	8'h15,
	8'h80,
    8'h10,

    // Window Size: 0x007C (multiply by 64=5888)
    // Checksum: 0xB8E0 (correct)
    8'h00,
	8'h7c,
	8'hb8,
    8'he0,

    // Urgent pointer: 0x0000
    // Options: (20 bytes)
    //         NOP: 0x01
    //         NOP: 0x01
    8'h00,
	8'h00,
	8'h01,
    8'h01,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h08,
	8'h0a,
	8'h00,
    8'h04,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
	8'h1c,
	8'ha4,
	8'h03,
    8'hbb,

    //         Timestamps: 0x080a00041C8F03BB5B77 TSval 269455, TSecr 62610295 (Kind=8 Length=10 TSval TSecr)
    8'h5b,
	8'h8c,
	8'h00,
    8'h00
  };


  
  
  
  // ============================================================= 
  // ARP_SERV_REPLY
  // =============================================================   
  //No.     Time        Source                Destination           Protocol Length Info
  //      2 0.000591    00:1A:A0:D5:CF:0F     Dell_4d:29:05         ARP      60     141.89.52.43 is at 00:1A:A0:D5:CF:0F

  //Frame 2: 60 bytes on wire (480 bits), 60 bytes captured (480 bits)
  //    Arrival Time: Nov  9, 2009 14:45:22.730842000 CET
  //    Epoch Time: 1257774322.730842000 seconds
  //    [Time delta from previous captured frame: 0.000591000 seconds]
  //    [Time delta from previous displayed frame: 0.000591000 seconds]
  //    [Time since reference or first frame: 0.000591000 seconds]
  //    Frame Number: 2
  //    Frame Length: 60 bytes (480 bits)
  //    Capture Length: 60 bytes (480 bits)
  //    [Frame is marked: False]
  //    [Frame is ignored: False]
  //    [Protocols in frame: eth:arp]
  //    [Coloring Rule Name: ARP]
  //    [Coloring Rule String: arp]
  //Ethernet II, Src: 00:1A:A0:D5:CF:0F (00:1A:A0:D5:CF:0F), Dst: Dell_4d:29:05 (00:1c:23:4d:29:05)
  //    Destination: Dell_4d:29:05 (00:1c:23:4d:29:05)
  //        Address: Dell_4d:29:05 (00:1c:23:4d:29:05)
  //        .... ...0 .... .... .... .... = IG bit: Individual address (unicast)
  //        .... ..0. .... .... .... .... = LG bit: Globally unique address (factory default)
  //    Source: 00:1A:A0:D5:CF:0F (00:1A:A0:D5:CF:0F)
  //        Address: 00:1A:A0:D5:CF:0F (00:1A:A0:D5:CF:0F)
  //        .... ...0 .... .... .... .... = IG bit: Individual address (unicast)
  //        .... ..1. .... .... .... .... = LG bit: Locally administered address (this is NOT the factory default)
  //    Type: ARP (0x0806)
  //    Trailer: 0000f84ad216010008090a0b0c0d0e0f1011
  //Address Resolution Protocol (reply)
  //    Hardware type: Ethernet (1)
  //    Protocol type: IP (0x0800)
  //    Hardware size: 6
  //    Protocol size: 4
  //    Opcode: reply (2)
  //    [Is gratuitous: False]
  //    Sender MAC address: 00:1A:A0:D5:CF:0F (00:1A:A0:D5:CF:0F)
  //    Sender IP address: 141.89.52.43 (141.89.52.43)
  //    Target MAC address: Dell_4d:29:05 (00:1c:23:4d:29:05)
  //    Target IP address: 141.89.52.200 (141.89.52.200)

  const bit [7:0] ARP_SERV_REPLY [] = '{
    8'h00,
    8'h1c,
    8'h23,
    8'h4d,
    8'h29,
    8'h05,
    8'h00,
    8'h1a,
    8'ha0,
    8'hd5,
    8'hcf,
    8'h0f,
    8'h08,
    8'h06,
    8'h00,
    8'h01,
    8'h08,
    8'h00,
    8'h06,
    8'h04,
    8'h00,
    8'h02,
    8'h00,
    8'h1a,
    8'ha0,
    8'hd5,
    8'hcf,
    8'h0f,
    8'h8d,
    8'h59,
    8'h34,
    8'h2b,
    8'h00,
    8'h1c,
    8'h23,
    8'h4d,
    8'h29,
    8'h05,
    8'h8d,
    8'h59,
    8'h34,
    8'hc8  		
  };  
  
  
  
  // ============================================================= 
  // ICMP_SERV_REPLY
  // =============================================================   
  //No.     Time        Source                Destination           Protocol Length Info
  //      4 0.001151    141.89.52.43          141.89.52.200         ICMP     98     Echo (ping) reply    id=0xeb67, seq=1/256, ttl=64

  //Frame 4: 98 bytes on wire (784 bits), 98 bytes captured (784 bits)
  //Ethernet II, Src: 00:1A:A0:D5:CF:0F (00:1A:A0:D5:CF:0F), Dst: Dell_4d:29:05 (00:1c:23:4d:29:05)
  //    Destination: Dell_4d:29:05 (00:1c:23:4d:29:05)
  //        Address: Dell_4d:29:05 (00:1c:23:4d:29:05)
  //        .... ...0 .... .... .... .... = IG bit: Individual address (unicast)
  //        .... ..0. .... .... .... .... = LG bit: Globally unique address (factory default)
  //    Source: 00:1A:A0:D5:CF:0F (00:1A:A0:D5:CF:0F)
  //        Address: 00:1A:A0:D5:CF:0F (00:1A:A0:D5:CF:0F)
  //        .... ...0 .... .... .... .... = IG bit: Individual address (unicast)
  //        .... ..1. .... .... .... .... = LG bit: Locally administered address (this is NOT the factory default)
  //    Type: IP (0x0800)
  //Internet Protocol Version 4, Src: 141.89.52.43 (141.89.52.43), Dst: 141.89.52.200 (141.89.52.200)
  //    Version: 4
  //    Header length: 20 bytes
  //    Differentiated Services Field: 0x00 (DSCP 0x00: Default; ECN: 0x00: Not-ECT (Not ECN-Capable Transport))
  //        0000 00.. = Differentiated Services Codepoint: Default (0x00)
  //        .... ..00 = Explicit Congestion Notification: Not-ECT (Not ECN-Capable Transport) (0x00)
  //    Total Length: 84
  //    Identification: 0x9e5b (40539)
  //    Flags: 0x00
  //        0... .... = Reserved bit: Not set
  //        .0.. .... = Don't fragment: Not set
  //        ..0. .... = More fragments: Not set
  //    Fragment offset: 0
  //    Time to live: 64
  //    Protocol: ICMP (1)
  //    Header checksum: 0x584a [correct]
  //        [Good: True]
  //        [Bad: False]
  //    Source: 141.89.52.43 (141.89.52.43)
  //    Destination: 141.89.52.200 (141.89.52.200)
  //Internet Control Message Protocol
  //    Type: 0 (Echo (ping) reply)
  //    Code: 0
  //    Checksum: 0x760a [correct]
  //    Identifier (BE): 60263 (0xeb67)
  //    Identifier (LE): 26603 (0x67eb)
  //    Sequence number (BE): 1 (0x0001)
  //    Sequence number (LE): 256 (0x0100)
  //    [Response To: 3]
  //    [Response Time: 0.539 ms]
  //    Data (56 bytes)
  //        Data: f21cf84abe210b0008090a0b0c0d0e0f1011121314151617...
  //        [Length: 56]
  
  const bit [7:0] ICMP_SERV_REPLY [] = '{
  	8'h00, 
  	8'h1c, 
  	8'h23, 
  	8'h4d,
  	8'h29, 
  	8'h05, 
  	8'h00, 
  	8'h1a, 
  	8'ha0, 
  	8'hd5, 
  	8'hcf, 
  	8'h0f, 
  	8'h08, 
  	8'h00, 
  	8'h45, 
  	8'h00, 
  	8'h00, 
  	8'h54, 
  	8'h00, 
  	8'h00, 
  	8'h40, 
  	8'h00, 
  	8'h40, 
  	8'h01, 
  	8'hb7, 
  	8'h03, 
  	8'h8d, 
  	8'h59, 
  	8'h34, 
  	8'h2b, 
  	8'h8d, 
  	8'h59, 
  	8'h34, 
  	8'hc8, 
  	8'h00, 
  	8'h00, 
  	8'h76, 
  	8'h0a, 
  	8'heb, 
  	8'h67, 
  	8'h00, 
  	8'h01,
  	8'hf2,
  	8'h1c, 
  	8'hf8, 
  	8'h4a, 
  	8'hbe, 
  	8'h21,
  	8'h0b, 
  	8'h00, 
  	8'h08, 
  	8'h09, 
  	8'h0a, 
  	8'h0b, 
  	8'h0c, 
  	8'h0d, 
  	8'h0e, 
  	8'h0f, 
  	8'h10, 
  	8'h11, 
  	8'h12, 
  	8'h13, 
  	8'h14, 
  	8'h15, 
  	8'h16, 
  	8'h17, 
  	8'h18, 
  	8'h19, 
  	8'h1a, 
  	8'h1b, 
  	8'h1c, 
  	8'h1d, 
  	8'h1e, 
  	8'h1f, 
  	8'h20, 
  	8'h21, 
  	8'h22, 
  	8'h23, 
  	8'h24, 
  	8'h25, 
  	8'h26, 
  	8'h27, 
  	8'h28, 
  	8'h29, 
  	8'h2a, 
  	8'h2b, 
  	8'h2c, 
  	8'h2d, 
  	8'h2e, 
  	8'h2f, 
  	8'h30, 
  	8'h31, 
  	8'h32, 
  	8'h33, 
  	8'h34, 
  	8'h35, 
  	8'h36,
  	8'h37
  };

  
  // ============================================================= 
  // TCP_SERV_SYNC_ACK_REPLY
  // =============================================================   
  const bit [7:0] TCP_SERV_SYNC_ACK_REPLY [] = '{
  	8'h00, 
  	8'h1c, 
  	8'h23,
  	8'h4d,
  	8'h29,
  	8'h05,
  	8'h00,
  	8'h1a,
  	8'ha0,
  	8'hd5,
  	8'hcf,
  	8'h0f,
  	8'h08,
  	8'h00,
  	8'h45,
  	8'h00,
  	8'h00,
  	8'h3c,
  	8'h00,
  	8'h01,
  	8'h40,
  	8'h00,
  	8'h40,
  	8'h06,
  	8'hb7,
  	8'h15,
  	8'h8d,
  	8'h59,
  	8'h34,
  	8'h2b, 
  	8'h8d,
  	8'h59,
  	8'h34,
  	8'hc8, 
  	8'he2,
  	8'h8c,
  	8'hdf,
  	8'hcc,
  	8'hc4,
  	8'hb3,
  	8'h44,
  	8'h0f,
  	8'h8a,
  	8'h20,
  	8'h64,
  	8'h23,
  	8'ha0, 
  	8'h12,
  	8'h16,
  	8'ha0,
  	8'h78,
  	8'h84,
  	8'h00,
  	8'h00,
  	8'h02,
  	8'h04,
  	8'h05,
  	8'hb4,
  	8'h04,
  	8'h02,
  	8'h08,
  	8'h0a,
  	8'h03,
  	8'hbb,
  	8'h5b,
  	8'h77,
  	8'h00,
  	8'h04,
  	8'h1c,
  	8'h8f,
  	8'h01,
  	8'h03,
  	8'h03,
  	8'h07
  };
  
    
  // ============================================================= 
  // TCP_SERV_GIOP_REQ_ACK_REPLY
  // =============================================================   
  const bit [7:0] TCP_SERV_GIOP_REQ_ACK_REPLY [] = '{ 
  	8'h00,
  	8'h1c, 
  	8'h23, 
  	8'h4d,
  	8'h29,
  	8'h05,
  	8'h00,
  	8'h1a,
  	8'ha0,
  	8'hd5,
  	8'hcf,
  	8'h0f,
  	8'h08,
  	8'h00,
  	8'h45,
  	8'h00,
  	8'h00,
  	8'h34,
  	8'h00,
  	8'h02,
  	8'h40,
  	8'h00,
  	8'h40,
  	8'h06,
  	8'hb7,
  	8'h1c,
  	8'h8d,
  	8'h59,
  	8'h34,
  	8'h2b,
  	8'h8d,
  	8'h59,
  	8'h34,
  	8'hc8,
  	8'he2,
  	8'h8c,
  	8'hdf,
  	8'hcc,
  	8'hc4,
  	8'hb3,
  	8'h44,
  	8'h10,
  	8'h8a,
  	8'h20,
  	8'h64,
  	8'h87,
  	8'h80,
  	8'h10,
  	8'h00,
  	8'h2e,
  	8'hbd,
  	8'h5e,
  	8'h00,
  	8'h00,
  	8'h01,
  	8'h01,
  	8'h08,
  	8'h0a,
  	8'h03,
  	8'hbb,
  	8'h5b,
  	8'h77,
  	8'h00,
  	8'h04,
  	8'h1c,
  	8'h8f
  };
  
  // ============================================================= 
  // TCP_SERV_GIOP_DATA_XMIT
  // =============================================================   
  const bit [7:0] TCP_SERV_GIOP_DATA_XMIT [] = '{
  	8'h24,
  	8'h81,
  	8'h09,
  	8'h63,
  	8'h0d,
  	8'h8d,
  	8'h65,
  	8'h12,
  	8'h01,
  	8'h0d,
  	8'h76,
  	8'h3d,
  	8'hed,
  	8'h8c,
  	8'hf9,
  	8'hc6,
  	8'hc5,
  	8'haa,
  	8'he5,
  	8'h77,
  	8'h12,
  	8'h8f,
  	8'hf2,
  	8'hce,
  	8'he8,
  	8'hc5,
  	8'h5c,
  	8'hbd,
  	8'h2d,
  	8'h65,
  	8'h63,
  	8'h0a
 };

  // ============================================================= 
  // TCP_SERV_GIOP_DATA_REPLY
  // =============================================================   
  const bit [7:0] TCP_SERV_GIOP_DATA_REPLY [] = '{
  	8'h00,
  	8'h1c,
  	8'h23,
  	8'h4d,
  	8'h29,
  	8'h05,
  	8'h00,
  	8'h1a,
  	8'ha0,
  	8'hd5,
  	8'hcf,
  	8'h0f,
  	8'h08,
  	8'h00,
  	8'h45,
  	8'h00,
  	8'h00,
  	8'h70,
  	8'h00,
  	8'h03,
  	8'h40,
  	8'h00,
  	8'h40,
  	8'h06,
  	8'hb6,
  	8'hdf,
  	8'h8d,
  	8'h59,
  	8'h34,
  	8'h2b,
  	8'h8d,
  	8'h59,
  	8'h34,
  	8'hc8,
  	8'he2,
  	8'h8c,
  	8'hdf,
  	8'hcc,
  	8'hc4,
  	8'hb3,
  	8'h44,
  	8'h10,
  	8'h8a,
  	8'h20,
  	8'h64,
  	8'h87,
  	8'h80,
  	8'h18,
  	8'h00,
  	8'h2e,
  	8'h5d,
  	8'he8,
  	8'h00,
  	8'h00,
  	8'h01,
  	8'h01,
  	8'h08,
  	8'h0a,
  	8'h03,
  	8'hbb,
  	8'h5b,
  	8'h77,
  	8'h00,
  	8'h04,
  	8'h1c,
  	8'h8f,
  	8'h47,
  	8'h49,
  	8'h4f,
  	8'h50,
  	8'h01,
  	8'h02,
  	8'h01,
  	8'h01,
  	8'h30,
  	8'h00,
  	8'h00,
  	8'h00,
  	8'h01,
  	8'h00,
  	8'h00,
  	8'h00,
  	8'h00,
  	8'h00,
  	8'h00,
  	8'h00,
  	8'h00,
  	8'h00,
  	8'h00,
  	8'h00,
  	8'h10,
  	8'h00,
  	8'h00,
  	8'h00,
  	8'h24,
  	8'h81,
  	8'h09, 
  	8'h63,
  	8'h0d,
  	8'h8d,
  	8'h65,
  	8'h12,
  	8'h01,
  	8'h0d, 
  	8'h76,
  	8'h3d,
  	8'hed,
  	8'h8c,
  	8'hf9,
  	8'hc6,
  	8'hc5,
  	8'haa,
  	8'he5,
  	8'h77,
  	8'h12,
  	8'h8f,
  	8'hf2,
  	8'hce,
  	8'he8,
  	8'hc5,
  	8'h5c,
  	8'hbd,
  	8'h2d,
  	8'h65,
  	8'h63,
  	8'h0a
  };
  	
  
  // ============================================================= 
  // TCP_SERV_FIN_ACK_REPLY
  // =============================================================   
  const bit [7:0] TCP_SERV_FIN_ACK_REPLY [] = '{
	8'h00,
	8'h1c,
	8'h23,
	8'h4d,
	8'h29,
	8'h05,
	8'h00, 
	8'h1a,
	8'ha0,
	8'hd5,
	8'hcf,
	8'h0f,
	8'h08,
	8'h00,
	8'h45,
	8'h00,
	8'h00,
	8'h34,
	8'h00,
	8'h04,
	8'h40,
	8'h00,
	8'h40,
	8'h06,
	8'hb7,
	8'h1a,
	8'h8d,
	8'h59,
	8'h34,
	8'h2b,
	8'h8d,
	8'h59,
	8'h34,
	8'hc8,
	8'he2,
	8'h8c,
	8'hdf,
	8'hcc,
	8'hc4,
	8'hb3,
	8'h44,
	8'h4c,
	8'h8a,
	8'h20,
	8'h64,
	8'h88,
	8'h80,
	8'h11,
	8'h00,
	8'h2e,
	8'hbc,
	8'hf6,
	8'h00,
	8'h00,
	8'h01,
	8'h01,
	8'h08,
	8'h0a,
	8'h03,
	8'hbb,
	8'h5b,
	8'h8c,
	8'h00,
	8'h04,
	8'h1c,
	8'ha4
  };

	
endpackage : eth_intrfc_top_pkg