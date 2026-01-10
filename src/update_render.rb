# frozen_string_literal: true
require "dotenv/load"
require "http"
require "base64"
require "date"
require_relative "pixels"

API_URL = "http://#{ENV["PIXOO_IP"]}/post"
ACCENT = [0x48, 0xb0, 0xd5]

PIC_SIZE = 64
CALENDAR_HEIGHT = 6 * 6 + 1
EVENTS_HEADER_WIDTH = 4 * 5 + 1
EVENTS_TEXT_WIDTH = PIC_SIZE - EVENTS_HEADER_WIDTH
SCROLL_SPEED = 1

MONTH_NAMES = %w[
  January
  February
  March
  April
  May
  June
  July
  August
  September
  October
  November
  December
].freeze

def draw_calendar
  holidays = JSON.load_file("./calendar/holidays.json")
  num_weeks = 6
  current_month_start = Date.new(Date.today.year, Date.today.month, 1)
  draw_start = current_month_start.next_day(-current_month_start.wday)
  draw_start = draw_start.next_day(-7) if draw_start.month == Date.today.month
  draw_end = draw_start.next_day(7 * num_weeks - 1)
  week = -1

  bg_pixels = Pixels.new(PIC_SIZE, CALENDAR_HEIGHT)
  text_pixels = Pixels.new(PIC_SIZE, CALENDAR_HEIGHT)

  today_week =
    (draw_start..draw_end).find_index { |date| date == Date.today } / 7

  bg_pixels.draw_rect(Date.today.wday * 9, 0, 9, 6 * num_weeks + 1, ACCENT, 0.2)
  bg_pixels.draw_rect(0, today_week * 6, PIC_SIZE, 7, ACCENT, 0.2)

  event_files = Dir.glob("./calendar/events/*.json")
  events =
    event_files.map { |f| JSON.parse(File.read(f), symbolize_names: true) }

  (draw_start..draw_end).each do |date|
    week += 1 if date.wday.zero?
    x_root = ((date.wday) * 9) + 1
    y_root = (week * 6) + 1

    color =
      if holidays.key?(date.strftime("%Y-%m-%d"))
        [255, 100, 100]
      elsif date.sunday?
        [255, 80, 80]
      elsif date.saturday?
        [80, 80, 255]
      else
        [255, 255, 255]
      end

    opacity =
      if date == Date.today
        1.0
      elsif date.month != Date.today.month
        0.35
      else
        0.7
      end

    day_events =
      events.filter do |event_data|
        start_time = Time.parse(event_data[:start_time])
        end_time = Time.parse(event_data[:end_time])
        event_range = (start_time.to_date..end_time.to_date)
        event_range.cover?(date)
      end

    day_events[..3].each_with_index do |event_data, index|
      event_color =
        if event_data[:calendar_color]
          [
            event_data[:calendar_color][:r],
            event_data[:calendar_color][:g],
            event_data[:calendar_color][:b]
          ]
        else
          [255, 255, 255]
        end
      bg_pixels.draw_rect(
        x_root,
        y_root + 4 - index,
        7,
        1,
        event_color,
        0.6 * opacity
      )
    end

    date
      .day
      .to_s
      .rjust(2)
      .chars
      .each_with_index do |char, index|
        text_pixels.draw_small_char(
          char,
          x_root + index * 4,
          y_root,
          color,
          opacity
        )
      end
  end

  month_name = MONTH_NAMES[Date.today.month - 1]
  month_name_width = text_pixels.measure_small_string(month_name)
  erase_size = ((month_name_width + 2) / 8.0).ceil * 8
  text_pixels.erase_rect(
    PIC_SIZE - erase_size,
    CALENDAR_HEIGHT - 7,
    erase_size,
    7,
    0.5
  )
  text_pixels.draw_small_string(
    month_name,
    PIC_SIZE - month_name_width - 1,
    CALENDAR_HEIGHT - 6,
    ACCENT,
    1
  )

  result_canvas = Pixels.new(PIC_SIZE, CALENDAR_HEIGHT)
  result_canvas.put!(bg_pixels, 0, 0)
  result_canvas.put!(text_pixels, 0, 0)
  result_canvas
end

def draw_events(text_scroll = 0, hide_event_name: ENV["HIDE_EVENT_NAME"] == "1")
  event_files = Dir.glob("./calendar/events/*.json")
  events =
    event_files.map { |f| JSON.parse(File.read(f), symbolize_names: true) }
  now = Time.now
  events.reject! do |event|
    end_time = Time.parse(event[:end_time])
    end_time < now
  end
  events.sort_by! do |event|
    start_time = Time.parse(event[:start_time])
    [start_time, event[:title]]
  end

  height = PIC_SIZE - CALENDAR_HEIGHT
  header_pixels = Pixels.new(EVENTS_HEADER_WIDTH, height)
  title_pixels = Pixels.new(EVENTS_TEXT_WIDTH, height)
  y_offset = 0
  text_widths = []

  events.each do |event_data|
    next if y_offset > height

    color =
      if event_data[:calendar_color]
        [
          event_data[:calendar_color][:r],
          event_data[:calendar_color][:g],
          event_data[:calendar_color][:b]
        ]
      else
        [255, 255, 255]
      end

    random_size = event_data[:start_time].hash % 10 + 5

    title = (hide_event_name ? ("●" * random_size) : event_data[:title])
    start_time = Time.parse(event_data[:start_time])
    current_date = Date.today
    text_width = title_pixels.measure_misaki_string(title)
    max_scroll = [0, text_width - EVENTS_TEXT_WIDTH + 1].max
    text_widths << title_pixels.draw_misaki_string(
      title,
      1 - [text_scroll, max_scroll].min,
      y_offset,
      color,
      start_time.to_date == current_date ? 1.0 : 0.3
    )

    header_str =
      if start_time.to_date == current_date
        start_time.strftime("%H:%M")
      else
        start_time.strftime("%m/%d")
      end
    header_str.chars.each_with_index do |char, index|
      header_pixels.draw_small_char(
        char,
        1 + index * 4,
        y_offset + 1,
        color,
        start_time.to_date == current_date ? 1.0 : 0.3
      )
    end

    y_offset += 9
  end

  result_canvas = Pixels.new(PIC_SIZE, height)
  result_canvas.put!(header_pixels, 0, 0)
  result_canvas.put!(title_pixels, EVENTS_HEADER_WIDTH, 0)
  [result_canvas, text_widths]
end

def run_update_render(hide_event_name: ENV["HIDE_EVENT_NAME"] == "1")
  pic_id = 1
  pix_speed = 100
  calendar_canvas = draw_calendar

  _events_canvas, event_text_widths =
    draw_events(0, hide_event_name: hide_event_name)
  max_scroll = event_text_widths.max + 1

  scroll_needed = max_scroll > EVENTS_TEXT_WIDTH
  scroll_steps =
    (
      if scroll_needed
        ((max_scroll - EVENTS_TEXT_WIDTH).to_f / SCROLL_SPEED).ceil
      else
        0
      end
    )
  stop_steps = 1
  frames = (scroll_needed ? scroll_steps + stop_steps * 2 - 1 : 1)
  frames = [frames, 60].min
  puts "Total scroll steps: #{scroll_steps}"
  puts "Total frames to upload: #{frames}"
  frame_index = 0

  maybe_pic_id =
    JSON.parse(
      HTTP.post(API_URL, json: { "Command" => "Draw/GetHttpGifId" }).body.to_s
    )
  raise "Failed to get PicID: #{maybe_pic_id}" unless maybe_pic_id["PicId"]
  pic_id = maybe_pic_id["PicId"]
  puts "Using PicID: #{pic_id}"

  (0..scroll_steps).each do |scroll_offset|
    events_canvas, _ =
      draw_events(
        scroll_offset * SCROLL_SPEED,
        hide_event_name: hide_event_name
      )
    final_canvas = Pixels.new(PIC_SIZE, PIC_SIZE)
    final_canvas.put!(calendar_canvas, 0, 0)
    final_canvas.put!(events_canvas, 0, CALENDAR_HEIGHT + 1)
    pixel_data = final_canvas.pack_data

    repeat =
      if not scroll_needed
        1
      elsif scroll_offset.zero? || scroll_offset == scroll_steps
        stop_steps
      else
        1
      end

    repeat.times do
      break if frame_index >= frames
      puts "Generating frame #{frame_index + 1}/#{frames}"
      command = {
        "Command" => "Draw/SendHttpGif",
        "PicNum" => frames,
        "PicWidth" => PIC_SIZE,
        "PicOffset" => frame_index,
        "PicID" => pic_id,
        "PixSpeed" => pix_speed,
        "PicData" => Base64.strict_encode64(pixel_data)
      }
      frame_index += 1
      res =
        HTTP
          .post(API_URL, json: command)
          .then { |response| JSON.parse(response.body.to_s) }
      raise "Failed to send command list: #{res}" if res["error_code"] != 0
    end
  end
end

run_update_render if $PROGRAM_NAME == __FILE__
