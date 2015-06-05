module Concerns::TicketConcern
  extend ActiveSupport::Concern

    def build_ticket_body_attributes
      if params[cname][:description] || params[cname][:description_html]
        unless params[cname].has_key?(:ticket_body_attributes)
          ticket_body_hash = {:ticket_body_attributes => { :description => params[cname][:description],
                                  :description_html => params[cname][:description_html] }} 
          params[cname].merge!(ticket_body_hash).tap do |t| 
            t.delete(:description) if t[:description]
            t.delete(:description_html) if t[:description_html]
          end 
        end 
      end
    end
end