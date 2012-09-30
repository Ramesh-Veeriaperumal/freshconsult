module MailAutolink
  
  def self.included(base)
    base.class_eval do
      include ClassMethods
      alias_method_chain :deliver!, :autolink
    end
  end

  module ClassMethods
    
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::TagHelper
        
    def deliver_with_autolink!(mail=@mail)
      #Does mail contain parts?
      if(!mail.parts.blank?)
        #if first part is multipart/mixed then delete --> temporary fix
        if(mail.parts[0].content_type == "multipart/mixed" && mail.parts[0].body.blank?)
          mail.parts.delete_at(0)
        end
        #send parts for auto_link
        auto_link_section(mail.parts)
      # if no parts and content is html then auto_link
      elsif(mail.content_type == "text/html")
        mail.body = auto_link(mail.body, :link => :urls)
      end
      
      deliver_without_autolink!(mail)
    end
    
    private 
      def auto_link_section(section)
        section.each do |sub_section|
          if(sub_section.content_type == "text/html" && sub_section.content_disposition != "attachment")
            sub_section.body = auto_link(sub_section.body, :link => :urls)
          end
          auto_link_section(sub_section.parts) unless sub_section.parts.blank?
        end
      end
  end
  
end

ActionMailer::Base.send :include, MailAutolink