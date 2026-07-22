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
  float2 texture_coordinate;
};

vertex DisplayVertex
 display_vertex( uint vertex_id [[vertex_id]] )
{
  const float2 positions[] = {
    float2( -1.0,  1.0 ), float2( -1.0, -1.0 ),
    float2(  1.0,  1.0 ), float2(  1.0, -1.0 ),
  };
  const float2 texture_coordinates[] = {
    float2( 0.0, 0.0 ), float2( 0.0, 1.0 ),
    float2( 1.0, 0.0 ), float2( 1.0, 1.0 ),
  };
  const uint indices[] = { 0, 1, 2, 2, 1, 3 };
  DisplayVertex output;
  uint index = indices[vertex_id];

  output.position = float4( positions[index], 0.0, 1.0 );
  output.texture_coordinate = texture_coordinates[index];
  return output;
}

fragment float4
 display_fragment( DisplayVertex input [[stage_in]],
                   texture2d<float> texture [[texture( 0 )]],
                   sampler texture_sampler [[sampler( 0 )]] )
{
  return texture.sample( texture_sampler, input.texture_coordinate );
}
