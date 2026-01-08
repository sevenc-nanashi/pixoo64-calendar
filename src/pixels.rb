# frozen_string_literal: true
require_relative "misaki"

class Pixels
  attr_reader :width, :height, :data

  SMALL_FONT = {
    "0" => <<~EOS,
      .#.
      #.#
      #.#
      #.#
      .#.
    EOS
    "1" => <<~EOS,
      .#.
      ##.
      .#.
      .#.
      .#.
    EOS
    "2" => <<~EOS,
      ##.
      ..#
      .#.
      #..
      ###
    EOS
    "3" => <<~EOS,
      ##.
      ..#
      .#.
      ..#
      ##.
    EOS
    "4" => <<~EOS,
      ..#
      .#.
      #.#
      ###
      ..#
    EOS
    "5" => <<~EOS,
      ###
      #..
      ##.
      ..#
      ##.
    EOS
    "6" => <<~EOS,
      .#.
      #..
      ##.
      #.#
      .#.
    EOS
    "7" => <<~EOS,
      ###
      ..#
      .#.
      .#.
      .#.
    EOS
    "8" => <<~EOS,
      .#.
      #.#
      .#.
      #.#
      .#.
    EOS
    "9" => <<~EOS
      .#.
      #.#
      .##
      ..#
      .#.
    EOS
  }

  def initialize(width, height = nil)
    @width = width
    @height = height || width
    @data = Array.new(@height) { Array.new(@width) { [0.0, 0.0, 0.0, 0.0] } }
  end

  def draw_small_char(char, offset_x, offset_y, color, alpha = 1.0)
    return if char == " "
    pattern = SMALL_FONT[char]
    return unless pattern

    pattern.lines.each_with_index do |line, y|
      line.chomp.chars.each_with_index do |pixel, x|
        next if pixel == "."
        set_pixel(offset_x + x, offset_y + y, color, alpha)
      end
    end
  end

  def draw_misaki_char(char, offset_x, offset_y, color, alpha = 1.0)
    pixels = MisakiGothic.instance.get_pixels_of_char(char)
    pixels.each_with_index do |row, y|
      row.each_with_index do |pixel, x|
        next unless pixel
        set_pixel(offset_x + x, offset_y + y, color, alpha)
      end
    end

    pixels[0].length
  end

  def draw_misaki_string(string, offset_x, offset_y, color, alpha = 1.0)
    x = offset_x
    string.each_char do |ch|
      char_width = draw_misaki_char(ch, x, offset_y, color, alpha)
      x += char_width
    end
  end

  def draw_rect(x0, y0, width, height, color, alpha = 1.0)
    (y0...(y0 + height)).each do |y|
      (x0...(x0 + width)).each { |x| set_pixel(x, y, color, alpha) }
    end
  end
  def draw_rect_outline(x0, y0, width, height, color, alpha = 1.0)
    (x0...(x0 + width)).each do |x|
      set_pixel(x, y0, color, alpha)
      set_pixel(x, y0 + height - 1, color, alpha)
    end
    ((y0 + 1)...(y0 + height - 1)).each do |y|
      set_pixel(x0, y, color, alpha)
      set_pixel(x0 + width - 1, y, color, alpha)
    end
  end

  def pack_data
    bytes =
      @data
        .flatten(1)
        .flat_map { |r, g, b, _a| [r.to_i, g.to_i, b.to_i] }
        .map { |v| [[v, 0].max, 255].min }
    bytes.pack("C*")
  end

  def put!(other, offset_x, offset_y, alpha = 1.0)
    other.data.each_with_index do |row, y|
      row.each_with_index do |(r, g, b, a), x|
        scaled_alpha = a * alpha
        next if scaled_alpha.zero?
        blend_premult_pixel(
          offset_x + x,
          offset_y + y,
          r * alpha,
          g * alpha,
          b * alpha,
          scaled_alpha
        )
      end
    end
    self
  end

  private

  def set_pixel(x, y, color, alpha)
    return if x < 0 || x >= @width || y < 0 || y >= @height
    a = [[alpha, 0.0].max, 1.0].min
    r0, g0, b0, a0 = @data[y][x]
    r = color[0] * a
    g = color[1] * a
    b = color[2] * a
    inv_a = 1.0 - a
    @data[y][x] = [
      r + r0 * inv_a,
      g + g0 * inv_a,
      b + b0 * inv_a,
      [a + a0 * inv_a, 1.0].min
    ]
  end

  def blend_premult_pixel(x, y, r, g, b, alpha)
    return if x < 0 || x >= @width || y < 0 || y >= @height
    a = [[alpha, 0.0].max, 1.0].min
    r0, g0, b0, a0 = @data[y][x]
    inv_a = 1.0 - a
    @data[y][x] = [
      r + r0 * inv_a,
      g + g0 * inv_a,
      b + b0 * inv_a,
      [a + a0 * inv_a, 1.0].min
    ]
  end
end
