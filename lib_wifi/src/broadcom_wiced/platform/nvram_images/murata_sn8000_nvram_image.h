// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef __wifi_murata_sn8000_nvram_image_h__
#define __wifi_murata_sn8000_nvram_image_h__

/** Murata SN8000 module
 *  Broadcom BCM43362 radio
 */
static const char wifi_nvram_image[] =
  "manfid=0x2d0"                                            "\x00"
  "prodid=0x4336"                                           "\x00"
  "vendid=0x14e4"                                           "\x00"
  "devid=0x4343"                                            "\x00"
  "boardtype=0x0598"                                        "\x00"
  "boardrev=0x1207"                                         "\x00"
  "boardnum=777"                                            "\x00"
  "xtalfreq=26000"                                          "\x00"
  "clkreq_conf=1"                                           "\x00"
  "boardflags=0xa00"                                        "\x00"
  "sromrev=3"                                               "\x00"
  "wl0id=0x431b"                                            "\x00"
  "macaddr=00:90:4c:07:71:12"                               "\x00"
  "aa2g=1"                                                  "\x00"
  "ag0=2"                                                   "\x00"
  "maxp2ga0=78"                                             "\x00"
  "ofdm2gpo=0x54321111"                                     "\x00"
  "mcs2gpo0=0x4444"                                         "\x00"
  "mcs2gpo1=0x8765"                                         "\x00"
  "pa0b0=0x14B8"                                            "\x00"
  "pa0b1=0xFD5C"                                            "\x00"
  "pa0b2=0xFF27"                                            "\x00"
  "pa0itssit=62"                                            "\x00"
  "pa1itssit=62"                                            "\x00"
  "cck2gpo=0"                                               "\x00"
  "cckPwrOffset=0"                                          "\x00"
  "cckdigfilttype=22"                                       "\x00"
  "ccode=0"                                                 "\x00"
  "rssismf2g=0xa"                                           "\x00"
  "rssismc2g=0x3"                                           "\x00"
  "rssisav2g=0x7"                                           "\x00"
  "rfreg033=0x19"                                           "\x00"
  "rfreg033_cck=0x1f"                                       "\x00"
  "triso2g=1"                                               "\x00"
  "noise_cal_enable_2g=0"                                   "\x00"
  "pacalidx2g=10"                                           "\x00"
  "swctrlmap_2g=0x0c050c05,0x0a030a03,0x0a030a03,0x0,0x1ff" "\x00"
  "RAW1=4a 0b ff ff 20 04 d0 02 62 a9"                      "\x00"
  "logen_mode=0x0,0x2,0x1b,0x0,0x1b"                        "\x00"
  "noise_cal_po_2g=2"                                       "\x00"
  "noise_cal_dbg.fab.3=1"                                   "\x00"
  "noise_cal_high_gain.fab.3=76"                            "\x00"
  "noise_cal_nf_substract_val.fab.3=356"                    "\x00"
  "noise_cal_po_2g.fab.3=4"                                 "\x00"
  "\x00\x00";

#endif // __wifi_murata_sn8000_nvram_image_h__
