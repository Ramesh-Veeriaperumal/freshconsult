module HelpdeskReports
  module Export
    module Query
      
      # Methods defined
      # def execute_archive_query(ticket_ids)
      # def execute_non_archive_query(ticket_ids)
      ["non_archive", "archive"].each do |type|
        define_method("execute_#{type}_query") do |ticket_ids|
          Sharding.run_on_slave { send("#{type}_tickets",ticket_ids) }
        end
      end
      
      def non_archive_tickets(ticket_ids)
        tickets = []
        Account.current.tickets.includes(ticket_associations_include).where(id: ticket_ids).find_in_batches(:batch_size => 300) do |tkts|
          tickets << tkts
        end
        tickets.flatten
      end
      
      def archive_tickets(ticket_ids)
        tickets = []
        Account.current.archive_tickets.includes(archive_associations_include).where(id: ticket_ids).find_in_batches(:batch_size => 300) do |tkts|
          tickets << tkts
        end
        tickets.flatten
      end
      
      def ticket_associations_include
        [ {:flexifield => [:flexifield_def]}, {:requester => [:company] }, :schema_less_ticket, :ticket_status, :group, :responder, :tags ]
      end
      
      def archive_associations_include
        [ {:flexifield => [:flexifield_def]}, {:requester => [:company] }, :archive_ticket_association, :ticket_status, :group, :responder, :tags]
      end
      
    end
  end
end