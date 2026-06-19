#include "config.h"

#include <stdio.h>

#include "test.h"

test_return_t
snap_custom_rom_flag_and_custom_rom_pages_getter_setter( void )
{
  /* libspectrum_snap: custom_rom flag and custom_rom_pages getter/setter */
  libspectrum_snap *snap = libspectrum_snap_alloc();
  test_return_t r = TEST_FAIL;

  if( !snap ) {
    fprintf( stderr, "%s: snap_custom_rom_flag_and_custom_rom_pages_getter_setter: snap_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_snap_custom_rom( snap ) != 0 ) {
    fprintf( stderr, "%s: snap_custom_rom_flag_and_custom_rom_pages_getter_setter: default custom_rom should be 0, got %d\n",
             progname, libspectrum_snap_custom_rom( snap ) );
    goto done;
  }

  libspectrum_snap_set_custom_rom( snap, 1 );
  if( libspectrum_snap_custom_rom( snap ) != 1 ) {
    fprintf( stderr, "%s: snap_custom_rom_flag_and_custom_rom_pages_getter_setter: expected custom_rom=1, got %d\n",
             progname, libspectrum_snap_custom_rom( snap ) );
    goto done;
  }

  libspectrum_snap_set_custom_rom( snap, 0 );
  if( libspectrum_snap_custom_rom( snap ) != 0 ) {
    fprintf( stderr, "%s: snap_custom_rom_flag_and_custom_rom_pages_getter_setter: expected custom_rom=0, got %d\n",
             progname, libspectrum_snap_custom_rom( snap ) );
    goto done;
  }

  if( libspectrum_snap_custom_rom_pages( snap ) != 0 ) {
    fprintf( stderr, "%s: snap_custom_rom_flag_and_custom_rom_pages_getter_setter: default custom_rom_pages should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_snap_custom_rom_pages( snap ) );
    goto done;
  }

  libspectrum_snap_set_custom_rom_pages( snap, 2 );
  if( libspectrum_snap_custom_rom_pages( snap ) != 2 ) {
    fprintf( stderr, "%s: snap_custom_rom_flag_and_custom_rom_pages_getter_setter: expected custom_rom_pages=2, got %lu\n",
             progname, (unsigned long)libspectrum_snap_custom_rom_pages( snap ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_snap_free( snap );
  return r;
}

test_return_t
snap_ram_pages_getter_setter( void )
{
  /* libspectrum_snap: RAM pages getter/setter */
  libspectrum_snap *snap = libspectrum_snap_alloc();
  libspectrum_byte *page;
  test_return_t r = TEST_FAIL;

  if( !snap ) {
    fprintf( stderr, "%s: snap_ram_pages_getter_setter: snap_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_snap_pages( snap, 0 ) != NULL ) {
    fprintf( stderr, "%s: snap_ram_pages_getter_setter: default pages[0] should be NULL\n", progname );
    goto done;
  }

  page = libspectrum_new( libspectrum_byte, 0x4000 );
  page[0] = 0xaa;
  page[0x3fff] = 0x55;

  libspectrum_snap_set_pages( snap, 0, page );
  if( libspectrum_snap_pages( snap, 0 ) != page ) {
    fprintf( stderr, "%s: snap_ram_pages_getter_setter: pages[0] pointer mismatch after set\n", progname );
    libspectrum_free( page );
    goto done;
  }

  if( libspectrum_snap_pages( snap, 0 )[0] != 0xaa ||
      libspectrum_snap_pages( snap, 0 )[0x3fff] != 0x55 ) {
    fprintf( stderr, "%s: snap_ram_pages_getter_setter: pages[0] data mismatch\n", progname );
    goto done;
  }

  if( libspectrum_snap_pages( snap, 1 ) != NULL ) {
    fprintf( stderr, "%s: snap_ram_pages_getter_setter: pages[1] should still be NULL\n", progname );
    goto done;
  }

  r = TEST_PASS;

done:
  /* snap_free frees all pages including the one we set */
  libspectrum_snap_free( snap );
  return r;
}

test_return_t
snap_interface1_active_paged_and_drive_count_getter_setter( void )
{
  /* libspectrum_snap: interface1 active, paged, and drive_count getter/setter */
  libspectrum_snap *snap = libspectrum_snap_alloc();
  test_return_t r = TEST_FAIL;

  if( !snap ) {
    fprintf( stderr, "%s: snap_interface1_active_paged_and_drive_count_getter_setter: snap_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_snap_interface1_active( snap ) != 0 ) {
    fprintf( stderr, "%s: snap_interface1_active_paged_and_drive_count_getter_setter: default interface1_active should be 0, got %d\n",
             progname, libspectrum_snap_interface1_active( snap ) );
    goto done;
  }

  libspectrum_snap_set_interface1_active( snap, 1 );
  if( libspectrum_snap_interface1_active( snap ) != 1 ) {
    fprintf( stderr, "%s: snap_interface1_active_paged_and_drive_count_getter_setter: expected interface1_active=1, got %d\n",
             progname, libspectrum_snap_interface1_active( snap ) );
    goto done;
  }

  if( libspectrum_snap_interface1_paged( snap ) != 0 ) {
    fprintf( stderr, "%s: snap_interface1_active_paged_and_drive_count_getter_setter: default interface1_paged should be 0, got %d\n",
             progname, libspectrum_snap_interface1_paged( snap ) );
    goto done;
  }

  libspectrum_snap_set_interface1_paged( snap, 1 );
  if( libspectrum_snap_interface1_paged( snap ) != 1 ) {
    fprintf( stderr, "%s: snap_interface1_active_paged_and_drive_count_getter_setter: expected interface1_paged=1, got %d\n",
             progname, libspectrum_snap_interface1_paged( snap ) );
    goto done;
  }

  if( libspectrum_snap_interface1_drive_count( snap ) != 0 ) {
    fprintf( stderr, "%s: snap_interface1_active_paged_and_drive_count_getter_setter: default interface1_drive_count should be 0, got %d\n",
             progname, libspectrum_snap_interface1_drive_count( snap ) );
    goto done;
  }

  libspectrum_snap_set_interface1_drive_count( snap, 4 );
  if( libspectrum_snap_interface1_drive_count( snap ) != 4 ) {
    fprintf( stderr, "%s: snap_interface1_active_paged_and_drive_count_getter_setter: expected interface1_drive_count=4, got %d\n",
             progname, libspectrum_snap_interface1_drive_count( snap ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_snap_free( snap );
  return r;
}

test_return_t
snap_ay_registers_array_getter_setter_all_16_registers( void )
{
  /* libspectrum_snap: ay_registers array getter/setter */
  libspectrum_snap *snap = libspectrum_snap_alloc();
  test_return_t r = TEST_FAIL;
  int i;

  if( !snap ) {
    fprintf( stderr, "%s: snap_ay_registers_array_getter_setter_all_16_registers: snap_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  /* Default: all 16 AY registers should be zero */
  for( i = 0; i < 16; i++ ) {
    if( libspectrum_snap_ay_registers( snap, i ) != 0 ) {
      fprintf( stderr, "%s: snap_ay_registers_array_getter_setter_all_16_registers: default ay_registers[%d] should be 0, got %d\n",
               progname, i, libspectrum_snap_ay_registers( snap, i ) );
      goto done;
    }
  }

  /* Set each register to a unique value and verify round-trip */
  for( i = 0; i < 16; i++ )
    libspectrum_snap_set_ay_registers( snap, i, (libspectrum_byte)(i + 1) );

  for( i = 0; i < 16; i++ ) {
    if( libspectrum_snap_ay_registers( snap, i ) != (libspectrum_byte)(i + 1) ) {
      fprintf( stderr, "%s: snap_ay_registers_array_getter_setter_all_16_registers: expected ay_registers[%d]=%d, got %d\n",
               progname, i, i + 1, libspectrum_snap_ay_registers( snap, i ) );
      goto done;
    }
  }

  r = TEST_PASS;

done:
  libspectrum_snap_free( snap );
  return r;
}

test_return_t
snap_divide_pages_count_and_divide_eprom_pointer_getter_setter( void )
{
  /* libspectrum_snap: DivIDE pages count and divide_eprom single-pointer */
  libspectrum_snap *snap = libspectrum_snap_alloc();
  libspectrum_byte *eprom;
  test_return_t r = TEST_FAIL;

  if( !snap ) {
    fprintf( stderr, "%s: snap_divide_pages_count_and_divide_eprom_pointer_getter_setter: snap_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_snap_divide_pages( snap ) != 0 ) {
    fprintf( stderr, "%s: snap_divide_pages_count_and_divide_eprom_pointer_getter_setter: default divide_pages should be 0, got %zu\n",
             progname, libspectrum_snap_divide_pages( snap ) );
    goto done;
  }
  libspectrum_snap_set_divide_pages( snap, 3 );
  if( libspectrum_snap_divide_pages( snap ) != 3 ) {
    fprintf( stderr, "%s: snap_divide_pages_count_and_divide_eprom_pointer_getter_setter: expected divide_pages=3, got %zu\n",
             progname, libspectrum_snap_divide_pages( snap ) );
    goto done;
  }

  if( libspectrum_snap_divide_eprom( snap, 0 ) != NULL ) {
    fprintf( stderr, "%s: snap_divide_pages_count_and_divide_eprom_pointer_getter_setter: default divide_eprom[0] should be NULL\n", progname );
    goto done;
  }

  eprom = libspectrum_new( libspectrum_byte, 0x2000 );
  eprom[0]      = 0xde;
  eprom[0x1fff] = 0xad;

  libspectrum_snap_set_divide_eprom( snap, 0, eprom );
  if( libspectrum_snap_divide_eprom( snap, 0 ) != eprom ) {
    fprintf( stderr, "%s: snap_divide_pages_count_and_divide_eprom_pointer_getter_setter: divide_eprom[0] pointer mismatch after set\n", progname );
    libspectrum_free( eprom );
    goto done;
  }
  if( libspectrum_snap_divide_eprom( snap, 0 )[0]      != 0xde ||
      libspectrum_snap_divide_eprom( snap, 0 )[0x1fff] != 0xad ) {
    fprintf( stderr, "%s: snap_divide_pages_count_and_divide_eprom_pointer_getter_setter: divide_eprom[0] data mismatch\n", progname );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_snap_free( snap );
  return r;
}

test_return_t
snap_divide_ram_page_pointer_array_getter_setter( void )
{
  /* libspectrum_snap: DivIDE RAM page pointer array (SNAPSHOT_DIVIDE_PAGES pages) */
  libspectrum_snap *snap = libspectrum_snap_alloc();
  libspectrum_byte *page0, *page1;
  test_return_t r = TEST_FAIL;

  if( !snap ) {
    fprintf( stderr, "%s: snap_divide_ram_page_pointer_array_getter_setter: snap_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_snap_divide_ram( snap, 0 ) != NULL ) {
    fprintf( stderr, "%s: snap_divide_ram_page_pointer_array_getter_setter: default divide_ram[0] should be NULL\n", progname );
    goto done;
  }

  page0 = libspectrum_new( libspectrum_byte, 0x2000 );
  page0[0]      = 0x11;
  page0[0x1fff] = 0x22;

  libspectrum_snap_set_divide_ram( snap, 0, page0 );
  if( libspectrum_snap_divide_ram( snap, 0 ) != page0 ) {
    fprintf( stderr, "%s: snap_divide_ram_page_pointer_array_getter_setter: divide_ram[0] pointer mismatch after set\n", progname );
    libspectrum_free( page0 );
    goto done;
  }
  if( libspectrum_snap_divide_ram( snap, 0 )[0]      != 0x11 ||
      libspectrum_snap_divide_ram( snap, 0 )[0x1fff] != 0x22 ) {
    fprintf( stderr, "%s: snap_divide_ram_page_pointer_array_getter_setter: divide_ram[0] data mismatch\n", progname );
    goto done;
  }

  page1 = libspectrum_new( libspectrum_byte, 0x2000 );
  page1[0] = 0x33;
  libspectrum_snap_set_divide_ram( snap, 1, page1 );

  if( libspectrum_snap_divide_ram( snap, 2 ) != NULL ) {
    fprintf( stderr, "%s: snap_divide_ram_page_pointer_array_getter_setter: divide_ram[2] should still be NULL\n", progname );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_snap_free( snap );
  return r;
}

test_return_t
snap_divmmc_active_eprom_writeprotect_paged_and_control_getter_setter( void )
{
  /* libspectrum_snap: DivMMC flags (active, eprom_writeprotect, paged, control) */
  libspectrum_snap *snap = libspectrum_snap_alloc();
  test_return_t r = TEST_FAIL;

  if( !snap ) {
    fprintf( stderr, "%s: snap_divmmc_active_eprom_writeprotect_paged_and_control_getter_setter: snap_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_snap_divmmc_active( snap ) != 0 ) {
    fprintf( stderr, "%s: snap_divmmc_active_eprom_writeprotect_paged_and_control_getter_setter: default divmmc_active should be 0, got %d\n",
             progname, libspectrum_snap_divmmc_active( snap ) );
    goto done;
  }
  libspectrum_snap_set_divmmc_active( snap, 1 );
  if( libspectrum_snap_divmmc_active( snap ) != 1 ) {
    fprintf( stderr, "%s: snap_divmmc_active_eprom_writeprotect_paged_and_control_getter_setter: expected divmmc_active=1, got %d\n",
             progname, libspectrum_snap_divmmc_active( snap ) );
    goto done;
  }

  if( libspectrum_snap_divmmc_eprom_writeprotect( snap ) != 0 ) {
    fprintf( stderr, "%s: snap_divmmc_active_eprom_writeprotect_paged_and_control_getter_setter: default divmmc_eprom_writeprotect should be 0, got %d\n",
             progname, libspectrum_snap_divmmc_eprom_writeprotect( snap ) );
    goto done;
  }
  libspectrum_snap_set_divmmc_eprom_writeprotect( snap, 1 );
  if( libspectrum_snap_divmmc_eprom_writeprotect( snap ) != 1 ) {
    fprintf( stderr, "%s: snap_divmmc_active_eprom_writeprotect_paged_and_control_getter_setter: expected divmmc_eprom_writeprotect=1, got %d\n",
             progname, libspectrum_snap_divmmc_eprom_writeprotect( snap ) );
    goto done;
  }

  if( libspectrum_snap_divmmc_paged( snap ) != 0 ) {
    fprintf( stderr, "%s: snap_divmmc_active_eprom_writeprotect_paged_and_control_getter_setter: default divmmc_paged should be 0, got %d\n",
             progname, libspectrum_snap_divmmc_paged( snap ) );
    goto done;
  }
  libspectrum_snap_set_divmmc_paged( snap, 1 );
  if( libspectrum_snap_divmmc_paged( snap ) != 1 ) {
    fprintf( stderr, "%s: snap_divmmc_active_eprom_writeprotect_paged_and_control_getter_setter: expected divmmc_paged=1, got %d\n",
             progname, libspectrum_snap_divmmc_paged( snap ) );
    goto done;
  }

  if( libspectrum_snap_divmmc_control( snap ) != 0x00 ) {
    fprintf( stderr, "%s: snap_divmmc_active_eprom_writeprotect_paged_and_control_getter_setter: default divmmc_control should be 0, got 0x%02x\n",
             progname, libspectrum_snap_divmmc_control( snap ) );
    goto done;
  }
  libspectrum_snap_set_divmmc_control( snap, 0xc7 );
  if( libspectrum_snap_divmmc_control( snap ) != 0xc7 ) {
    fprintf( stderr, "%s: snap_divmmc_active_eprom_writeprotect_paged_and_control_getter_setter: expected divmmc_control=0xc7, got 0x%02x\n",
             progname, libspectrum_snap_divmmc_control( snap ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_snap_free( snap );
  return r;
}

test_return_t
snap_divmmc_pages_count_and_divmmc_eprom_pointer_getter_setter( void )
{
  /* libspectrum_snap: DivMMC pages count and divmmc_eprom single-pointer */
  libspectrum_snap *snap = libspectrum_snap_alloc();
  libspectrum_byte *eprom;
  test_return_t r = TEST_FAIL;

  if( !snap ) {
    fprintf( stderr, "%s: snap_divmmc_pages_count_and_divmmc_eprom_pointer_getter_setter: snap_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_snap_divmmc_pages( snap ) != 0 ) {
    fprintf( stderr, "%s: snap_divmmc_pages_count_and_divmmc_eprom_pointer_getter_setter: default divmmc_pages should be 0, got %zu\n",
             progname, libspectrum_snap_divmmc_pages( snap ) );
    goto done;
  }
  libspectrum_snap_set_divmmc_pages( snap, 16 );
  if( libspectrum_snap_divmmc_pages( snap ) != 16 ) {
    fprintf( stderr, "%s: snap_divmmc_pages_count_and_divmmc_eprom_pointer_getter_setter: expected divmmc_pages=16, got %zu\n",
             progname, libspectrum_snap_divmmc_pages( snap ) );
    goto done;
  }

  if( libspectrum_snap_divmmc_eprom( snap, 0 ) != NULL ) {
    fprintf( stderr, "%s: snap_divmmc_pages_count_and_divmmc_eprom_pointer_getter_setter: default divmmc_eprom[0] should be NULL\n", progname );
    goto done;
  }

  eprom = libspectrum_new( libspectrum_byte, 0x4000 );
  eprom[0]      = 0xbe;
  eprom[0x3fff] = 0xef;

  libspectrum_snap_set_divmmc_eprom( snap, 0, eprom );
  if( libspectrum_snap_divmmc_eprom( snap, 0 ) != eprom ) {
    fprintf( stderr, "%s: snap_divmmc_pages_count_and_divmmc_eprom_pointer_getter_setter: divmmc_eprom[0] pointer mismatch after set\n", progname );
    libspectrum_free( eprom );
    goto done;
  }
  if( libspectrum_snap_divmmc_eprom( snap, 0 )[0]      != 0xbe ||
      libspectrum_snap_divmmc_eprom( snap, 0 )[0x3fff] != 0xef ) {
    fprintf( stderr, "%s: snap_divmmc_pages_count_and_divmmc_eprom_pointer_getter_setter: divmmc_eprom[0] data mismatch\n", progname );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_snap_free( snap );
  return r;
}

test_return_t
snap_zxatasp_ram_page_pointer_array_getter_setter( void )
{
  /* libspectrum_snap: ZXATASP RAM page pointer array (SNAPSHOT_ZXATASP_PAGES pages) */
  libspectrum_snap *snap = libspectrum_snap_alloc();
  libspectrum_byte *page0, *page1;
  test_return_t r = TEST_FAIL;

  if( !snap ) {
    fprintf( stderr, "%s: snap_zxatasp_ram_page_pointer_array_getter_setter: snap_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_snap_zxatasp_ram( snap, 0 ) != NULL ) {
    fprintf( stderr, "%s: snap_zxatasp_ram_page_pointer_array_getter_setter: default zxatasp_ram[0] should be NULL\n", progname );
    goto done;
  }

  page0 = libspectrum_new( libspectrum_byte, 0x4000 );
  page0[0]      = 0x11;
  page0[0x3fff] = 0x22;

  libspectrum_snap_set_zxatasp_ram( snap, 0, page0 );
  if( libspectrum_snap_zxatasp_ram( snap, 0 ) != page0 ) {
    fprintf( stderr, "%s: snap_zxatasp_ram_page_pointer_array_getter_setter: zxatasp_ram[0] pointer mismatch after set\n", progname );
    libspectrum_free( page0 );
    goto done;
  }
  if( libspectrum_snap_zxatasp_ram( snap, 0 )[0]      != 0x11 ||
      libspectrum_snap_zxatasp_ram( snap, 0 )[0x3fff] != 0x22 ) {
    fprintf( stderr, "%s: snap_zxatasp_ram_page_pointer_array_getter_setter: zxatasp_ram[0] data mismatch\n", progname );
    goto done;
  }

  page1 = libspectrum_new( libspectrum_byte, 0x4000 );
  page1[0] = 0x33;
  libspectrum_snap_set_zxatasp_ram( snap, 1, page1 );

  if( libspectrum_snap_zxatasp_ram( snap, 2 ) != NULL ) {
    fprintf( stderr, "%s: snap_zxatasp_ram_page_pointer_array_getter_setter: zxatasp_ram[2] should still be NULL\n", progname );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_snap_free( snap );
  return r;
}
