ActiveRecord::Base.class_eval do

  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::UrlHelper
  include WhiteListHelper
  include Utils::Unhtml

  def self.format_attribute(*attr_names)
    prepare(*attr_names)
    before_save :format_content
  end
  
  def self.unhtml_it(*attr_names)
    prepare(*attr_names)
    before_create :create_content
    before_update :update_content
  end
  
  def self.prepare(*attr_names)
    #include part will get ugly, if we are gonna use this for more than one attribute.. Shan
    self.send(:class_variable_set, '@@unhtmlable_attributes', attr_names)
    #class << self; include ActionView::Helpers::TagHelper, ActionView::Helpers::TextHelper, WhiteListHelper; end
    #define_method (:cname)  { self.class.name.demodulize.downcase }
  end

  def dom_id
    [self.class.name.downcase.pluralize.dasherize, id] * '-'
  end

  def create_content
    list = self.class.send(:class_variable_get,'@@unhtmlable_attributes')
    Rails.logger.debug ":::::create_content"
    populate_content_create(self,list)
  end


  protected
    def format_content
      format_list = self.class.send(:class_variable_get, '@@unhtmlable_attributes')
      format_list.each do |body|
        send(:read_attribute,body).strip! if send(:read_attribute,body).respond_to?(:strip!)
        self.send(:write_attribute , "#{body}_html", send(:read_attribute,body).blank? ? '' : body_html_with_formatting(send(:read_attribute,body)))
      end
    end
    
    def update_content # To do :: need to use changed_body_html?
      list = self.class.send(:class_variable_get,'@@unhtmlable_attributes')
      list.each do |body| 
        if send "#{body}_html_changed?"
          self.send(:write_attribute , "#{body}_html", Rinku.auto_link(self.send(:read_attribute , "#{body}_html"), :urls))
          self.send(:write_attribute , body, Helpdesk::HTMLSanitizer.plain(send(:read_attribute , "#{body}_html"))) 
        end  
      end   
    end
end