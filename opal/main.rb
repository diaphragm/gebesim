
# $opal -I ./ -c main.rb > main.js

require 'opal'
require 'native'
require 'math'

require 'bullet'
require "anime"
require "page"


$win = Native(`window`)

COLOR_MAP = {
  1 => 0xff0000,
  2 => 0xffff00,
  3 => 0x00ff00,
  4 => 0x00ffff,
  5 => 0x0000ff,
  6 => 0xff00ff,
  7 => 0x800000,
  8 => 0x808000,
  9 => 0x008000,
  10 => 0x008080,
  11 => 0x000080,
  12 => 0x800080,
  13 => 0x000000,
  14 => 0x808080,
  15 => 0xC0C0C0,
  16 => 0xFFFFFF,
}
COLOR_MAP.default_proc = ->(h,k){
  h[k] = rand(6)*0x33*0x10000 + rand(6)*0x33*0x100 + rand(6)*0x33
}

def debug(i)
  COLOR_MAP[i]
end

def onload(&block)
  `window.onload = block;`
end

onload do
  page_setup

  init_anime
#  init_bullet
#  init_tooltip
  animate

  fire unless $win.location.hash == ""
end
