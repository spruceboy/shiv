#!/usr/bin/env ruby
require "rubygems"
require "imlib2"

source_image = Imlib2::Image.load("test_tile.jpg")
water_mark_image = Imlib2::Image.load("aoos_logo3.png")

#old_ctx = Imlib2::Context.pop

#if (old_ctx.blend)
    #puts 'blend enabled.'
#end
#ctx = Imlib2::Context.new
#cmod = Imlib2::ColorModifier.new
#cmod.gamma = 0.5
#ctx.cmod = cmod
#Imlib2::Context.push(ctx)


#cmod = Imlib2::ColorModifier.new
#cmod.gamma = 0.5
#ctx = Imlib2::Context.get
#ctx.operation = Imlib2::Op::RESHADE
#ctx.cmod.gamma = 0.5

# adjust the gamma of the given rect
#cmod = Imlib2::ColorModifier.new
#cmod.gamma = 0.5
#cmod.contrast = 1.5
#image.apply_color_modifier(cmod)
#cmod.reset

src_rect = [ 0, 0,water_mark_image.width, water_mark_image.height ]
dst_rect = [ 60, 60, water_mark_image.width, water_mark_image.height ]

source_image.blend!(water_mark_image, src_rect, dst_rect, true)
