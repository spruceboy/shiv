require "rubygems"
require "curb"
require "imlib2"
require "tempfile"
require "thread"
require "pp"

Imlib2::Font.add_path("/usr/share/X11/fonts/Type1/")
Imlib2::Font.add_path("/usr/share/fonts/dejavu-lgc/")
#DejaVuLGCSans.ttf
@font = Imlib2::Font.new 'DejaVuLGCSans/24'

x = 1
y = 100
z = 30

i = 0
j = 0

im = Imlib2::Image.load(ARGV.first)
pp im.width
im.draw_text(@font, "#{x+i}/#{y+j}/#{z}",10,10,Imlib2::Color::AQUA)
im.set_format(".gif")
im.save(ARGV.last)


