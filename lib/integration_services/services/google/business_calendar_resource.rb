module IntegrationServices::Services
  module Google
    class BusinessCalendarResource < GoogleResource

      def holidays
        calendar_id = @service.payload["calendar_id"]
        events_list_url = "#{server_url}/calendar/v3/calendars/#{CGI.escape(calendar_id)}/events"
        response = http_get(events_list_url, {
          :key => api_key
        })
        process_response(response, 200) do |json_response|
          holidays_data = []
          temp = json_response["items"]
          temp.reject! { |item| item["start"]["date"].to_date.year != Date.today.year }
          holidays_data = temp.collect { |item| [item["start"]["date"].to_date, item["summary"]] }.sort!
          holidays_data.collect! { |hd| [Date::ABBR_MONTHNAMES[hd[0].month].to_s + " " + hd[0].day.to_s,hd[1]] }
          return holidays_data
        end
      end

    end
  end
end
