module HumanizeHelper
  
  include ActionView::Helpers::NumberHelper

  def humanize_stats number
    opts = number >= 1000 ? { :class => 'tooltip', :title => number_with_delimiter(number) } : {}
    content_tag(:span, number_to_human(number, 
                                    :units => Solution::Constants::HUMANIZE_STATS, 
                                    :precision => 1, 
                                    :significant => false).delete(' '), opts)
  end
end