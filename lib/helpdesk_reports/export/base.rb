module HelpdeskReports
  module Export
    class Base
      
      include ::Export::Util
      include HelpdeskReports::Export::Utils
            
      def initialize(args)
        args.symbolize_keys!
        set_current_account args[:account_id]
        set_current_user args[:user_id]
        set_locale
        TimeZone.set_time_zone
      end
        
    end
  end
end