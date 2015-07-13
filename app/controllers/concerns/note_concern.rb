module Concerns::NoteConcern
  extend ActiveSupport::Concern

    def build_note_body_attributes
      if params[cname][:body] || params[cname][:body_html]
        unless params[cname].has_key?(:note_body_attributes)
          note_body_hash = {:note_body_attributes => { :body => params[cname][:body],
                                  :body_html => params[cname][:body_html] }} 
          params[cname].merge!(note_body_hash).tap do |t| 
            t.delete(:body) if t[:body]
            t.delete(:body_html) if t[:body_html]
          end 
        end 
      end
    end
end