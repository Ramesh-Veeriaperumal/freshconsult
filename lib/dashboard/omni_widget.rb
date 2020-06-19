require_relative 'widget.rb'
# Explicitly requiring as eager loading causes issues due to class loading order
class Dashboard::OmniWidget < Dashboard::Widget
  attr_accessor :name, :width, :height, :x, :y, :source, :link, :title, :type, :url, :refresh_interval

  URL_PREFIX = '/api/data/widget-data?type='.freeze

  def initialize(data)
    @name = data[0]
    @width = data[1]
    @height = data[2]
    @source  = data[3]
    @type = data[4]
    @refresh_interval = data[5] if data[5].present?
    @title = I18n.t("omni_dashboard.#{@name.gsub('-', '_')}_title")
    @tooltip = I18n.t(data[6]) if data[6].present?
    if data[7].present?
      @link = {
        'link_text': data[8] && I18n.t(data[8]),
        'href': data[7]
      }
    end
    @url = @name == 'freshdesk-todo' ? '/api/_/todos' : (URL_PREFIX + data[0])
    @x = 0
    @y = 0
  end
end
