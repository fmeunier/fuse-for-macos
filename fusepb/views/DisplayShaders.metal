/* DisplayShaders.metal: Shared display shader entry points
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#include <metal_stdlib>

using namespace metal;

struct DisplayVertex {
  float4 position [[position]];
};

vertex DisplayVertex
 display_vertex( uint vertex_id [[vertex_id]] )
{
  const float2 positions[] = {
    float2( -1.0, -1.0 ),
    float2( 3.0, -1.0 ),
    float2( -1.0, 3.0 ),
  };
  DisplayVertex output;

  output.position = float4( positions[vertex_id], 0.0, 1.0 );
  return output;
}

fragment float4
 display_fragment()
{
  return float4( 0.0, 0.0, 0.0, 1.0 );
}
