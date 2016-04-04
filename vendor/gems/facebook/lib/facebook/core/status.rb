module Facebook
  module Core
    class Status < Facebook::Core::Post
      
      def initialize(fan_page, status_id, koala_post = nil)
        super(fan_page, status_id, koala_post)
        @type = POST_TYPE[:status]
      end
      
    end
  end
end

