require_relative 'widget.rb'
# Explicitly requiring as eager loading causes issues due to class loading order
class Dashboard::OmniWidget < Dashboard::Widget
  attr_accessor :name, :width, :height, :x, :y, :source, :tooltip, :detail_link, :detail_label

  URL_PREFIX = '/api/data/widget-data?type='.freeze

  def initialize(data)
    @name = data[0]
    @width = data[1]
    @height = data[2]
    @source  = data[3]
    @tooltip = data[4] && I18n.t(data[4])
    @detail_link = data[5]
    @detail_label = data[6] && I18n.t(data[6])
    @url = URL_PREFIX + data[3]
    @x = 0
    @y = 0
  end
end
