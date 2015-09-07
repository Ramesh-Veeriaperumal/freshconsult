module HelpdeskReports
  module Export
    module Query
      
      # Methods defined
      # def execute_archive_query(ticket_ids)
      # def execute_non_archive_query(ticket_ids)
      ["non_archive", "archive"].each do |type|
        define_method("execute_#{type}_query") do |ticket_ids|
           send("#{type}_tickets",ticket_ids)
        end
      end
      
      def non_archive_tickets(ticket_ids)
        tickets = []
        Account.current.tickets.includes(associations_include).where(id: ticket_ids).find_in_batches do |tkts|
          tickets << tkts
        end
        tickets.flatten
      end
      
      def archive_tickets(ticket_ids)
        # Handle for archive case when it comes @ARCHIVE
        []
      end
      
      def associations_include
        [ {:flexifield => [:flexifield_def]}, {:requester => [:company] }, :schema_less_ticket, :group, :responder, :tags ]
      end
    end
  end
end