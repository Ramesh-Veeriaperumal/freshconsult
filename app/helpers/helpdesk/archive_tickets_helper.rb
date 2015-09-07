module Helpdesk::ArchiveTicketsHelper
  include Helpdesk::TicketFilterMethods
  include Helpdesk::TicketsHelper
  include MetaHelperMethods
  
  def allowed_filter_options
    [:responder_id, :group_id, :created_at, :priority, :ticket_type, :source, 
      :customers, :requester, :products, :tags]  
  end

  def is_twitter_dm?(note)
    note.tweet && note.tweet.is_dm?
  end

  def is_facebook_message?(note)
    note.fb_post && note.fb_post.message?
  end

  def load_sticky
    render("helpdesk/archive_tickets/show/sticky")
  end

  def set_created_at_options(c_hash)
    if (c_hash[:name] == "created_at")
      c_hash[:options] = TicketConstants::ARCHIVE_CREATED_WITHIN_OPTIONS
    end
  end

  def ticket_pagination_html(options,full_pagination=false)
    prev = 0
    tickets_in_current_page = options[:tickets_in_current_page]
    current_page = options[:current_page]
    per_page = params[:per_page]
    no_of_pages = options[:total_pages]
    no_count_query = no_of_pages.nil? #no_of_pages can be nil, when no_list_view_count_query feature is enabled
    if no_count_query
      last_page = tickets_in_current_page==30 ? current_page+1 : current_page
    else
      last_page = no_of_pages
    end
    visible_pages = (full_pagination && !no_count_query) ? visible_page_numbers(options,current_page,no_of_pages) : []
    tooltip = 'tooltip' if !full_pagination

    content = ""
    content << "<div class='toolbar_pagination_full'>" if full_pagination
    if current_page == 1
      content << "<span class='disabled prev_page'>#{options[:previous_label]}</span>"
    else
      content << "<a class='prev_page #{tooltip}' href='/helpdesk/tickets/archived?page=#{(current_page-1)}' 
                      title='Previous' 
                      #{shortcut_options('previous') unless full_pagination} >#{options[:previous_label]}</a>"
    end

    unless no_count_query
      visible_pages.each do |index|
        # detect gaps:
        content << '<span class="gap">&hellip;</span>' if prev and index > prev + 1
        prev = index
        if( index == current_page )
          content << "<span class='current'>#{index}</span>"
        else
          content << "<a href='/helpdesk/tickets?page=#{index}' rel='next'>#{index}</a>"
        end
      end
    end

    if current_page == last_page
      content << "<span class='disabled next_page'>#{options[:next_label]}</span>"
    else
      content << "<a class='next_page #{tooltip}' href='/helpdesk/tickets?page=#{(current_page+1)}' 
                      rel='next' title='Next' 
                      #{shortcut_options('next') unless full_pagination} >#{options[:next_label]}</a>"
    end
    content << "</div>" if full_pagination
    content
  end

  def time_entry_note note
    note.gsub(/(\r\n|\n|\r)/, '<br />').html_safe
  end
end