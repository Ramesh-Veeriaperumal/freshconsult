class BootstrapPaginationRenderer < WillPaginate::LinkRenderer

  def initialize
    @gap_marker = '<li class="disabled gap"><a>&hellip;</a></li>'
  end

  def to_html
    links = @options[:page_links] ? windowed_links : []

    links.unshift(page_link_or_span(@collection.previous_page, 'previous', @options[:previous_label]))
    links.push(page_link_or_span(@collection.next_page, 'next', @options[:next_label]))

    html = @template.content_tag(:ul, links.join(@options[:separator]))
    @options[:container] ? @template.content_tag(:div, html, html_attributes) : html
  end

protected

  def windowed_links
    prev = nil

      visible_page_numbers.inject [] do |links, n|
        # detect gaps:
        links << gap_marker if prev and n > prev + 1
        links << page_link_or_span(n)
        prev = n
        links
      end

    # visible_page_numbers.map { |n| page_link_or_span(n, (n == current_page ? 'current' : nil)) }
  end

  def page_link_or_span(page, span_class = "", text = nil)
    text ||= page.to_s
    if page && page != current_page
      page_link(page, text, :class => span_class)
    else
      page_disabled_link(page, text, :class => span_class + (( %w(previous next).include? span_class) ? " disabled" : " active"))
    end
  end

  def page_link(page, text, attributes = {})
    @template.content_tag(:li, @template.link_to(text, url_for(page)), attributes)
  end

  def page_disabled_link(page, text, attributes = {})
    @template.content_tag(:li, @template.link_to(text, ""), attributes)
  end

end