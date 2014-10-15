# TODO-RAILS3 need to change this
# http://thewebfellas.com/blog/2010/8/22/revisited-roll-your-own-pagination-links-with-will_paginate-and-rails-3
class DefaultPaginationRenderer < WillPaginate::ActionView::LinkRenderer

  def initialize
    @gap_marker = '<span class="gap">&hellip;</span>'
  end
  
  def to_html
    links = @options[:page_links] ? windowed_links : []
    # previous/next buttons
    links.unshift page_link_or_span(@collection.previous_page, 'disabled prev_page', @options[:previous_label].html_safe)
    links.push    page_link_or_span(@collection.next_page,     'disabled next_page', @options[:next_label].html_safe)

    html = links.join(@options[:separator]).html_safe
    (@options[:container] ? @template.content_tag(:div, html, container_attributes) : html).html_safe
  end

  protected
  def page_link_or_span(page, span_class, text = nil)
    text ||= page.to_s

    if page and page != current_page
      classnames = span_class && span_class.index(' ') && span_class.split(' ', 2).last
      page_link page, text, :rel => rel_value(page), :class => classnames
    else
      page_span page, text, :class => span_class
    end
  end

  def page_link(page, text, attributes = {})
    @template.link_to text.html_safe, url(page).html_safe, attributes
  end

  def page_span(page, text, attributes = {})
    @template.content_tag :span, text.html_safe, attributes
  end
end
