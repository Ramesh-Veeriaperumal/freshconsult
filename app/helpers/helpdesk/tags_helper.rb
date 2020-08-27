module Helpdesk::TagsHelper

  MINT_DISABLED_TAG_LINKS = ["Archive", "Customers"]

  def sort_menu
    %(
      <div class="fd-menu" id="SortMenu" style="display:none; margin-left:-5px; margin-top:18px;">
        <ul>
          <li>
            <a class="wf_order tag_sort" href="#" data-wf-order="activity" >
              #{t('.usage')}
            </a>
          </li>
          <li>
            <a class="wf_order tag_sort" href="#" data-wf-order="name" >
              #{t('.name')}
            </a>
          </li>

        </ul>
        <span class="seperator"></span>
        <ul>
          <li>
            <a class="wf_order_type tag_sort_type" href="#" data-wf-order-type="asc" >
               #{t('.asc')}
            </a>
          </li>
          <li>
            <a class="wf_order_type tag_sort_type" href="#" data-wf-order-type="desc" >
               #{t('.desc')}
            </a>
          </li>
        </ul>
      </div>
      <a class="drop-right nav-trigger" href="#" menuid="#SortMenu">
        #{t('ticket.sort_by')} <b class="current_sort">  #{t('.usage')} </b>
      </a>
    ).html_safe
  end

  def ticket_tags_count(tag)
    if Account.current.count_es_enabled?
      action_hash = [{"condition" => "helpdesk_tags.id", "operator" => "is_in", "value" => tag.id }]
      negative_conditions = [{ "condition" => "spam", "operator" => "is", "value" => "true" },{ "condition" => "deleted", "operator" => "is", "value" => "true" }]
      Search::Tickets::Docs.new(action_hash, negative_conditions,false).count(Helpdesk::Ticket)
    else
      tags_count(tag, "Helpdesk::Ticket")
    end      
  end

  def tags_count tag, association
    Sharding.run_on_slave { Account.current.tag_uses.tags_count(tag.id, association).count }
    rescue => e
      t("many")
  end


  def current_tag_sort_order
     params[:sort] || cookies[:tag_sort_key] ||  "activity_desc"
  end
 
  def tag_search_text
    return @tags.first.name if params[:tag_id].present? and @tags.present?
    params[:name] || ""
  end

  def ticket_tags_filter_link(tag)
    %{/a/tickets/filters/search?q[]=tags:["#{safe_filter_tag(tag.name)}"]}
  end

  def tagged_module tag, dom_type, mod_count
    case dom_type
    when "Tickets"
      render :partial => 'tag_count', :locals => {
          :tag => tag,
          :count => mod_count,
          :plurals => [t('.ticket'), t('.tickets')],
          :type => "Helpdesk::Ticket",
          :tooltip => @archive_feature ? t('.recent_tickets') : t('.tickets'),
          :dom_type => dom_type,
          :link =>  ticket_tags_filter_link(tag),
          :image => "ticket"
      }
    when "Customers"
      render :partial => 'tag_count', :locals => {
          :tag => tag,
          :count => mod_count,
          :plurals => [t('.customer'),t('.customers')],
          :type => "User",
          :tooltip => t('.contacts'),
          :dom_type => dom_type,
          :link => "/contacts/filter/all?tag="+tag.id.to_s,
          :image => "user"
      }
    when "Articles"
      render :partial => 'tag_count', :locals => {
          :tag => tag,
          :count => mod_count,
          :plurals => [t('.article'),t('.articles')],
          :type => "Solution::Article",
          :tooltip => t('.articles'),
          :dom_type => dom_type,
          :link => "",
          :image => "article"
      }
    when "Archive"
      if current_account.features_included?(:archive_tickets)
        render :partial => 'tag_count', :locals => {
            :tag => tag,
            :count => mod_count,
            :plurals => [t('.archive ticket'),t('.archive tickets')],
            :type => "Helpdesk::ArchiveTicket",
            :tooltip => t('.archive_tickets'),
            :dom_type => dom_type,
            :link => "/helpdesk/tickets/archived/filter/tags/#{tag.id}",
            :image => "archived-ticket"

        }
      end
    end
  end

  # Custom function to escape double qoutes and backslash
  def safe_filter_tag(string)
    CGI.escape(string.gsub(/(\")/) { |match| '\\' + match })
  end
end
