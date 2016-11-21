require_relative '../../../test_helper'
module Ember
  module Tickets
    class ActivitiesControllerTest < ActionController::TestCase
      include TicketsTestHelper

      def wrap_cname(params)
        { merge: params }
      end
      
      def error_when_ticket_not_found
      end
      
      def error_when_ticket_not_permissible
         
      end
      
      def error_on_thrift_connection_issues
         
      end
      
      def error_on_thrift_other_issues
         
      end
      
      def survey_related_stuff 
         
      end
      
      def donot_show_user_email_when_no_permission
         
      end
      
      def handle_execute_scenario
      end
      
      def handle_add_watcher
      end
      
      def remove_watcher
      end
      
      def handle_add_cc
      end
      
      def handle_ticket_deletion
      end
      
      def handle_ticket_restore
      end
      
    end
  end
end