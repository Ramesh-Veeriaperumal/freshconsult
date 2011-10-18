ActiveRecord::Base.class_eval do
  include ActionView::Helpers::TagHelper, ActionView::Helpers::TextHelper,ActionView::Helpers::UrlHelper, WhiteListHelper
  def self.format_attribute(attr_name)
    prepare(attr_name)
    before_save :format_content
  end
  
  def self.unhtml_it(attr_name)
    prepare(attr_name)
    before_create :create_content
    before_update :update_content
  end
  
  def self.prepare(attr_name)
    #include part will get ugly, if we are gonna use this for more than one attribute.. Shan
    class << self; include ActionView::Helpers::TagHelper, ActionView::Helpers::TextHelper, WhiteListHelper; end
    define_method(:body)       { read_attribute attr_name }
    define_method(:body=)      { |value| write_attribute attr_name, value }
    define_method(:body_html)  { read_attribute "#{attr_name}_html" }
    define_method(:body_html=) { |value| write_attribute "#{attr_name}_html", value }
    define_method(:body_html_changed?)  { send "#{attr_name}_html_changed?" }
  end

  def dom_id
    [self.class.name.downcase.pluralize.dasherize, id] * '-'
  end

  protected
    def format_content
      body.strip! if body.respond_to?(:strip!)
      self.body_html = body.blank? ? '' : body_html_with_formatting
    end
    
    def body_html_with_formatting
      body_html = auto_link(body) { |text| truncate(text, 100) }
      textilized = RedCloth.new(body_html.gsub(/\n/, '<br />'), [ :hard_breaks ])
      textilized.hard_breaks = true if textilized.respond_to?("hard_breaks=")
      white_list(textilized.to_html)
    end
    
    def create_content
      if body.blank? && !body_html.blank?
        self.body = Helpdesk::HTMLSanitizer.plain(body_html)
      elsif body_html.blank? && !body.blank?
        self.body_html = body_html_with_formatting
      elsif body.blank? && body_html.blank?
        self.body = self.body_html = "Not given."
      end
    end
    
    def update_content
      self.body = Helpdesk::HTMLSanitizer.plain(body_html) if body_html_changed?
    end
end