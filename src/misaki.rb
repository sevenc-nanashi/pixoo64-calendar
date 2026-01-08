# frozen_string_literal: true
require "chunky_png"
require "singleton"

def jisx0208_kuten(ch)
  unless ch.is_a?(String) && ch.each_char.count == 1
    raise ArgumentError, "Need a single character string"
  end

  euc = ch.encode("EUC-JP")
  bytes = euc.bytes

  if bytes.length == 2 && (0xA1..0xFE).cover?(bytes[0]) &&
       (0xA1..0xFE).cover?(bytes[1])
    ku = bytes[0] - 0xA0
    ten = bytes[1] - 0xA0
    return ku, ten
  end

  # ここに来るのは ASCII / 半角カナ(0x8E..) / 補助漢字(0x8F..) / など
  nil
rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
  nil
end

class MisakiGothic
  include Singleton

  def initialize
    @misaki_4x8 = ChunkyPNG::Image.from_file("#{__dir__}/misaki/misaki_4x8.png")
    @misaki_gothic =
      ChunkyPNG::Image.from_file("#{__dir__}/misaki/misaki_gothic.png")
  end

  def get_pixels_of_char(ch)
    char = ch.encode("euc-jp", invalid: :replace, undef: :replace)
    cropped =
      if char.ord <= 0xff
        @misaki_4x8.crop((char.ord & 0x0f) * 4, (char.ord >> 4) * 8, 4, 8)
      else
        ku, ten = jisx0208_kuten(char)
        return get_pixels_of_char("？") unless ku && ten

        @misaki_gothic.crop((ten - 1) * 8, (ku - 1) * 8, 8, 8)
      end
    pixels = []
    cropped.height.times do |y|
      row = []
      cropped.width.times do |x|
        pixel = ChunkyPNG::Color.r(cropped[x, y])
        row << (pixel < 128)
      end
      pixels << row
    end
    pixels
  end
end
