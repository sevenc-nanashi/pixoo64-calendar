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
        0.3
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
      bg_pixels.draw_rect(x_root, y_root + 4 - index, 7, 1, event_color, 0.5)
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
  result_canvas = Pixels.new(PIC_SIZE, CALENDAR_HEIGHT)
  result_canvas.put!(bg_pixels, 0, 0)
  result_canvas.put!(text_pixels, 0, 0)
  result_canvas
end

def draw_events
  event_files = Dir.glob("./calendar/events/*.json")
  events =
    event_files.map { |f| JSON.parse(File.read(f), symbolize_names: true) }
  now = Time.now
  events.filter! do |event|
    end_time = Time.parse(event[:end_time])
    (now <= end_time) || (start_time.to_date == Date.today)
  end
  events.sort_by! do |event|
    start_time = Time.parse(event[:start_time])
    [start_time, event[:title]]
  end

  height = PIC_SIZE - CALENDAR_HEIGHT
  text_pixels = Pixels.new(PIC_SIZE, height)
  y_offset = 0

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

    title = event_data[:title]
    start_time = Time.parse(event_data[:start_time])
    current_date = Date.today
    text_pixels.draw_misaki_string(
      title,
      1,
      y_offset,
      color,
      start_time.to_date == current_date ? 1.0 : 0.5
    )

    y_offset += 9
  end
  text_pixels
end

def run_update_render
  pix_num = 1
  pic_id = 1
  pix_speed = 100

  final_canvas = Pixels.new(PIC_SIZE, PIC_SIZE)
  calendar_canvas = draw_calendar
  events_canvas = draw_events
  final_canvas.put!(calendar_canvas, 0, 0)
  final_canvas.put!(events_canvas, 0, CALENDAR_HEIGHT + 1)
  pixel_data = final_canvas.pack_data

  HTTP.post(API_URL, json: { "Command" => "Draw/ResetHttpGifId" })
  HTTP.post(
    API_URL,
    json: {
      "Command" => "Draw/SendHttpGif",
      "PicNum" => pix_num,
      "PicWidth" => PIC_SIZE,
      "PicOffset" => 0,
      "PicID" => pic_id,
      "PixSpeed" => pix_speed,
      "PicData" => Base64.strict_encode64(pixel_data)
    }
  )
end

puts run_update_render if $PROGRAM_NAME == __FILE__
