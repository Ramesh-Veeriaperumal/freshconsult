module Zoomclient
  module Actions
    module Meeting

      def meeting_list(*args)
        options = extract_options!(args)
        require_params(:host_id, options)
        process_datetime_params!(:start_time, options)
        parse_response self.class.post("/meeting/list", :query => options)
      end

      def meeting_create(*args)
        options = extract_options!(args)
        require_params([:host_id, :topic, :type], options)
        process_datetime_params!(:start_time, options)
        parse_response self.class.post("/meeting/create", :query => options)
      end

      def meeting_update(*args)
        options = extract_options!(args)
        require_params([:id, :host_id], options)
        process_datetime_params!(:start_time, options)
        parse_response self.class.post("/meeting/update", :query => options)
      end

      def meeting_delete(*args)
        options = extract_options!(args)
        require_params([:id, :host_id], options)
        parse_response self.class.post("/meeting/delete", :query => options)
      end

      def meeting_end(*args)
        options = extract_options!(args)
        require_params([:id, :host_id], options)
        parse_response self.class.post("/meeting/end", :query => options)
      end

      def meeting_get(*args)
        options = extract_options!(args)
        require_params([:id, :host_id], options)
        parse_response self.class.post("/meeting/get", :query => options)
      end
    end
  end
end
