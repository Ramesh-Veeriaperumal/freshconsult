module Helpdesk::HTMLSanitizer
  SANITIZE_CONFIG = Sanitize::Config::RELAXED.merge(:remove_contents => [ 'style' ])
  SANITIZE_CONFIG[:attributes].merge!('span' => ['style'])
  SANITIZE_CONFIG[:elements] << 'span'
  SANITIZE_CONFIG[:protocols].merge!('img' => {'src' => 'cid'})
  
  def self.clean(html)
    Sanitize.clean(html, SANITIZE_CONFIG) if html
  end
  
  def self.plain(html)
    Sanitize.clean(html) if html
  end
end
