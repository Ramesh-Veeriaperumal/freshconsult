module Utilities
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::UrlHelper
  include WhiteListHelper
  def body_html_with_formatting(body)
    body_html = auto_link(body) { |text| truncate(text, 100) }
    textilized = RedCloth.new(body_html.gsub(/\n/, '<br />'), [ :hard_breaks ])
    textilized.hard_breaks = true if textilized.respond_to?("hard_breaks=")
    white_list(textilized.to_html)
  end
end
