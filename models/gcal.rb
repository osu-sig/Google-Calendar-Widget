require 'htmlentities'
require_relative 'base'

class Gcal < Base
  def initialize
    super
    @max_per_tile = @config['max_per_tile']
    @student_url = @config['google']['calendar']['student_url']
    @staff_url = @config['google']['calendar']['staff_url']
    @student_calendar_days = 1
    @staff_calendar_days = 10
    @show_day_of_week = false
  end



  # Returns the student schedule for today.
  def student_schedule
    resp = get_calendar(@student_url, @student_calendar_days)
    parse_response(resp, :hide_dates => true, :message => "No students in today")
  end



  # Returns all the dates and times that staff will be out for the next 10 days.
  def staff_outages
    resp = get_calendar(@staff_url, @staff_calendar_days)
    parse_response(resp, :message => "No scheduled time off...")
  end




  private

  # Performs a rest API call to google calendar, pulls down relevant event information
  # Arguments: url (url), duration_in_days (integer)
  def get_calendar(url, duration_in_days)
    today = DateTime.now
    # Treats recurring events like other events. Gets all events starting between RIGHT NOW and this
    # => upcoming midnight. Orders them by start time, with closest first.
    get(url, :params => { 'alt'          => 'jsonc',
                          'singleevents' => 'true',
                          'start-min'    => today.to_s,
                          'start-max'    => (today + duration_in_days).to_date.to_datetime.to_s,
                          'orderby'      => 'starttime',
                          'sortorder'    => 'ascending'
                        })
  end



  # Parses response from google calendar into something the gcal widget can use.
  # Restricts the number of entries to the number that can fit on a tile.
  # Arguments: resp (response hash from google calendar)
  # Options: :hide_dates => boolean, :message => "string"
  # Conditions: @max_per_tile will determine how many entries get returned.
  # Returns { :entries => [array_of_entries], :conditional_more_info => "string" }
  def parse_response(resp, options = {})
    entries  = []
    conditional_more_info = ''

    if resp['data']['items'].blank?
      conditional_more_info = options[:message] || "No events"
    else

      resp['data']['items'].each do |entry|
        entries << build_entry(entry, options)
      end

    end

    # Since only N lines of text will fit on a tile, we need to restrict our returned results.
    # Because a notice takes up a line of text, only N-1 lines of data can be shown if entries > N.
    if entries.length > @max_per_tile
      conditional_more_info = "Showing #{ @max_per_tile - 1 } of #{ entries.length } events"
      entries = entries[0..(@max_per_tile - 2)]
    end

    { entries: entries, conditional_more_info: conditional_more_info, error: false }
  end



  # Builds an entry in the structure the gcal widget needs
  # Arguments: unbuilt_entry (hash from google calendar)
  # Options: :hide_dates => boolean
  # Returns: { :label => "string", :value => "string" }
  def build_entry(unbuilt_entry, options = {})
    parsed_dates_and_times =  parse_detail(unbuilt_entry['details'])
    entry = { label: parse_title(unbuilt_entry['title']) }

    if options[:hide_dates]
      date_time = parsed_dates_and_times[:times]
    else

      # In this block we add a comma between the dates and times, if there is one of each.
      if parsed_dates_and_times[:dates].blank? || parsed_dates_and_times[:times].blank?
        seperator = ""
      else
        seperator = ", "
      end

      date_time = parsed_dates_and_times[:dates] + seperator + parsed_dates_and_times[:times]
    end

    entry[:value] = date_time
    entry
  end



  # Returns the first word in the title as a string. Usually a person's first name.
  # Example:
  # parse_title("Stacy leaving early")
  # => "Stacy"
  def parse_title(title)
    # Lets decode any html entities we find
    title = HTMLEntities.new.decode title
    title = title.split(" ").first
    # If it ends with a period lets remove it and strip any non printing chars
    (title.end_with?('.')) ? title.chop!.strip : title.strip
  end



  # Parses the event's date and time. Date is in format "Mon Dec 12 - Tue Dec 13".
  # Time is in format "12:13pm - 2pm".
  # Arguments: detail (json object)
  # Conditions: @show_day_of_week determines whether the day of the week is shown
  # Returns { :dates => "string", :times => "string" }
  def parse_detail(detail)
    dates = []
    number_to_subtract = @show_day_of_week ? 10 : 6
    today = Date.today.strftime("%b %-d")
    # Grab the relevant section from the detail string e.g. after the
    # 'when' and stopping at either the end of the line or an html break
    detail = detail.match(/(?<=When: )(.*?)(?=<br |$)/).to_s
    # String out anything that's not alphanumeric, spaces, commas, or colins.
    detail.gsub!(/[^0-9A-Za-z ,:]/, '')
    year_index = detail.index(", 20")

    while year_index
      # Grab the date, without the year
      dates << detail[(year_index - number_to_subtract)..(year_index - 1)]
      # Because the first 9 days of a month are a single digit, we have to check if we will
      # go off the end of the string before taking a substring.
      start_index = year_index >= 10 ? year_index - 10 : year_index - 9
      # Remove date from detail, which leaves only times and subsequent dates.
      detail = detail.sub(detail[start_index..(year_index + 6)], "")
      year_index = detail.index(", 20")
    end

    times = detail.gsub(" ", "").split("to").join(" - ")
    dates = dates.uniq.join(" - ")
    dates.gsub!(today, "Today")
    { :dates => dates, :times => times }
  end
end