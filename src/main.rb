# frozen_string_literal: true
require "dotenv/load"
require "sinatra"
require "icalendar"
require "digest/md5"
require "json"
require "tzinfo"
require "time"
require_relative "update_render"

TIMEZONE = TZInfo::Timezone.get("Asia/Tokyo").utc_offset
EXCLUDE_CALENDARS = (ENV["EXCLUDE_CALENDARS"] || "").split(",")

AUTH_KEY = ENV.fetch("AUTH_KEY") { raise "AUTH_KEY is not set" }
before do
  provided_key = request.env["HTTP_AUTHORIZATION"]
  halt 401, "Unauthorized\n" unless provided_key == AUTH_KEY
end

def parse_colorcode(color_code)
  return nil unless color_code&.match?(/^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})$/)

  stripped_code = color_code.delete_prefix("#")
  if stripped_code.length == 6
    r = stripped_code[0..1].to_i(16)
    g = stripped_code[2..3].to_i(16)
    b = stripped_code[4..5].to_i(16)
  elsif stripped_code.length == 3
    r = (stripped_code[0] * 2).to_i(16)
    g = (stripped_code[1] * 2).to_i(16)
    b = (stripped_code[2] * 2).to_i(16)
  end
  { r: r, g: g, b: b }
end

get "/" do
  "OK"
end

post "/clean-events" do
  status 200
end

post "/push-events/begin" do
  Dir.mkdir("calendar/tmp_events") unless Dir.exist?("calendar/tmp_events")
  status 200
end

post "/push-events/append" do
  request.body.rewind
  calendar_data = request.body.read
  calendars = Icalendar::Calendar.parse(calendar_data.strip)
  calendars.each do |calendar|
    calendar.events.each do |event|
      sanitized_event_id = Digest::MD5.hexdigest(event.uid)
      uid =
        "#{event.dtstart.to_time.to_i}-#{event.dtend.to_time.to_i}-#{sanitized_event_id}"
      puts "Received event with UID: #{uid}"
      event_data = {
        uid: uid,
        title: event.summary.force_encoding("UTF-8"),
        start_time: event.dtstart.to_time.localtime(TIMEZONE).iso8601,
        end_time: event.dtend.to_time.localtime(TIMEZONE).iso8601,
        calendar_name:
          calendar.custom_properties["x_wr_calname"]&.first.force_encoding(
            "UTF-8"
          ),
        calendar_color:
          calendar.custom_properties["x_apple_calendar_color"]
            &.first
            &.then { |color| parse_colorcode(color) }
      }
      if EXCLUDE_CALENDARS.include?(event_data[:calendar_name])
        puts "Excluding event from calendar: #{event_data[:calendar_name]}"
        next
      end
      File.open("calendar/tmp_events/#{uid}.json", "w") do |file|
        file.write(JSON.pretty_generate(event_data))
      end
    end
  end
  status 200
end

post "/push-events/end" do
  FileUtils.rm_rf("calendar/events")
  FileUtils.mv("calendar/tmp_events", "calendar/events")

  status 200
end

post "/update" do
  File.open("./calendar/holidays.json", "w") do |file|
    response = HTTP.get("https://holidays-jp.github.io/api/v1/date.json")
    File.write(file, response.body.to_s)
  end

  begin
    run_update_render
    status 200
    { ok: true }.to_json
  rescue StandardError => e
    status 500
    warn e
    { ok: false, error: e.message }.to_json
  end
end

set :port, ENV.fetch("PORT", 4567)
set :bind, "0.0.0.0"
