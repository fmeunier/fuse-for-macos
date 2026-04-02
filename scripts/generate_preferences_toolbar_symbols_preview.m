#import <AppKit/AppKit.h>

typedef struct {
  __unsafe_unretained NSString *tab;
  __unsafe_unretained NSString *recommended;
  __unsafe_unretained NSString *alternate_a;
  __unsafe_unretained NSString *alternate_b;
} SymbolRow;

static SymbolRow symbol_rows[] = {
  { @"General", @"gearshape", @"slider.horizontal.3", @"gearshape" },
  { @"Sound", @"speaker.wave.2", @"speaker.wave.2", @"hifispeaker" },
  { @"Peripherals", @"externaldrive", @"puzzlepiece.extension", @"externaldrive.connected.to.line.below" },
  { @"Recording", @"record.circle", @"film", @"recordingtape" },
  { @"Inputs", @"gamecontroller", @"keyboard", @"gamecontroller.fill" },
  { @"ROM", @"memorychip", @"cpu", @"memorychip" },
  { @"Machine", @"desktopcomputer", @"desktopcomputer", @"pc" },
  { @"Video", @"display", @"sparkles.tv", @"display.trianglebadge.exclamationmark" },
};

static void
draw_text( NSString *string, NSRect rect, NSDictionary *attributes )
{
  [string drawInRect:rect withAttributes:attributes];
}

static void
draw_symbol_cell( NSString *symbol_name, NSRect rect,
                  NSDictionary *name_attributes )
{
  NSImage *image;
  NSImageSymbolConfiguration *configuration;
  NSRect image_rect, name_rect;

  [[NSColor colorWithWhite:0.98 alpha:1.0] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect( rect, 8.0, 6.0 )
                                   xRadius:10.0 yRadius:10.0] fill];

  configuration = [NSImageSymbolConfiguration configurationWithPointSize:26.0
                                                                  weight:NSFontWeightRegular];
  image = [NSImage imageWithSystemSymbolName:symbol_name
                       accessibilityDescription:nil];
  image = [image imageWithSymbolConfiguration:configuration];

  image_rect = NSMakeRect( NSMidX( rect ) - 16.0, NSMaxY( rect ) - 48.0, 32.0, 32.0 );
  if( image ) {
    [image drawInRect:image_rect];
  }

  name_rect = NSMakeRect( rect.origin.x + 12.0, rect.origin.y + 10.0,
                          rect.size.width - 24.0, 30.0 );
  draw_text( symbol_name, name_rect, name_attributes );
}

int
main( int argc, const char **argv )
{
  NSString *output_path;
  NSBitmapImageRep *bitmap;
  NSGraphicsContext *context;
  NSDictionary *title_attributes, *header_attributes, *tab_attributes, *name_attributes;
  NSColor *background_color;
  NSUInteger i;
  CGFloat width = 1400.0, height = 760.0;
  CGFloat left = 40.0, top = 38.0;
  CGFloat header_y, row_top;
  CGFloat tab_width = 180.0, column_width = 380.0, row_height = 76.0;
  NSArray *column_titles;

  @autoreleasepool {
    if( argc > 1 ) {
      output_path = [NSString stringWithUTF8String:argv[1]];
    } else {
      output_path = @"preferences-toolbar-symbols-preview.png";
    }

    bitmap = [[NSBitmapImageRep alloc]
      initWithBitmapDataPlanes:NULL pixelsWide:(NSInteger)width pixelsHigh:(NSInteger)height
      bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
      colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];

    background_color = [NSColor colorWithWhite:1.0 alpha:1.0];
    [background_color setFill];
    NSRectFill( NSMakeRect( 0.0, 0.0, width, height ) );

    title_attributes = @{
      NSFontAttributeName: [NSFont boldSystemFontOfSize:26.0],
      NSForegroundColorAttributeName: [NSColor colorWithWhite:0.15 alpha:1.0],
    };
    header_attributes = @{
      NSFontAttributeName: [NSFont boldSystemFontOfSize:17.0],
      NSForegroundColorAttributeName: [NSColor colorWithWhite:0.20 alpha:1.0],
    };
    tab_attributes = @{
      NSFontAttributeName: [NSFont systemFontOfSize:16.0 weight:NSFontWeightSemibold],
      NSForegroundColorAttributeName: [NSColor colorWithWhite:0.15 alpha:1.0],
    };
    name_attributes = @{
      NSFontAttributeName: [NSFont systemFontOfSize:14.0],
      NSForegroundColorAttributeName: [NSColor colorWithWhite:0.25 alpha:1.0],
      NSParagraphStyleAttributeName: ({
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        [style setAlignment:NSTextAlignmentCenter];
        style;
      }),
    };

    draw_text( @"Preferences Toolbar SF Symbols Preview",
               NSMakeRect( left, height - top - 34.0, width - 80.0, 36.0 ),
               title_attributes );
    draw_text( @"Recommended and alternate symbol sets rendered with AppKit.",
               NSMakeRect( left, height - top - 62.0, width - 80.0, 24.0 ),
               @{ NSFontAttributeName: [NSFont systemFontOfSize:15.0],
                  NSForegroundColorAttributeName: [NSColor colorWithWhite:0.4 alpha:1.0] } );

    column_titles = @[ @"Recommended", @"Alternate A", @"Alternate B" ];
    header_y = height - 130.0;
    draw_text( @"Tab", NSMakeRect( left, header_y, tab_width, 24.0 ), header_attributes );
    for( i = 0; i < [column_titles count]; i++ ) {
      draw_text( [column_titles objectAtIndex:i],
                 NSMakeRect( left + tab_width + i * column_width, header_y,
                             column_width, 24.0 ),
                 header_attributes );
    }

    for( i = 0; i < sizeof( symbol_rows ) / sizeof( symbol_rows[0] ); i++ ) {
      NSRect row_rect;

      row_top = height - 180.0 - i * row_height;
      row_rect = NSMakeRect( left, row_top - row_height + 8.0,
                             width - left * 2.0, row_height - 8.0 );
      [[NSColor colorWithWhite:( i % 2 ) ? 0.985 : 0.965 alpha:1.0] setFill];
      NSRectFill( row_rect );

      draw_text( symbol_rows[i].tab,
                 NSMakeRect( left + 8.0, row_top - 44.0, tab_width - 16.0, 28.0 ),
                 tab_attributes );

      draw_symbol_cell( symbol_rows[i].recommended,
                        NSMakeRect( left + tab_width, row_top - row_height + 4.0,
                                    column_width, row_height ),
                        name_attributes );
      draw_symbol_cell( symbol_rows[i].alternate_a,
                        NSMakeRect( left + tab_width + column_width, row_top - row_height + 4.0,
                                    column_width, row_height ),
                        name_attributes );
      draw_symbol_cell( symbol_rows[i].alternate_b,
                        NSMakeRect( left + tab_width + column_width * 2.0,
                                    row_top - row_height + 4.0,
                                    column_width, row_height ),
                        name_attributes );
    }

    [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
      writeToFile:output_path atomically:YES];

    [NSGraphicsContext restoreGraphicsState];
  }

  return 0;
}
