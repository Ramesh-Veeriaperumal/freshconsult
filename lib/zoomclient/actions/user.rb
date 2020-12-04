module Zoomclient
  module Actions
    module User

      def user_list(*args)
        options = extract_options!(args)
        parse_response self.class.post('/user/list', :query => options)
      end

      def user_create_meeting(*args)
        options = extract_options!(args)
        require_params([:host_id, :topic, :type], options)
        process_datetime_params!(:start_time, options)
        parse_response self.class.post("/users/#{options.delete(:host_id)}/meetings", body: options.to_json)
      end

      def user_pending(*args)
        options = extract_options!(args)
        parse_response self.class.post('/user/pending', :query => options)
      end

      def user_create(*args)
        options = extract_options!(args)
        require_params([:type, :email], options)
        parse_response self.class.post('/user/create', :query => options)
      end

      def user_delete(*args)
        options = extract_options!(args)
        require_params([:id], options)
        parse_response self.class.post('/user/delete', :query => options)
      end

      def user_permanent_delete(*args)
        options = extract_options!(args)
        require_params([:id], options)
        parse_response self.class.post('/user/permanentdelete', :query => options)
      end

      def user_update(*args)
        options = extract_options!(args)
        require_params([:id], options)
        parse_response self.class.post('/user/update', :query => options)
      end

      def user_get(*args)
        options = extract_options!(args)
        require_params([:id], options)
        parse_response self.class.post('/user/get', :query => options)
      end

      def user_getbyemail(*args)
        options = extract_options!(args)
        require_params([:email], options)
        parse_response self.class.post('/user/getbyemail', :query => options)
      end
    end
  end
end
