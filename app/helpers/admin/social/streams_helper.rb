require_dependency "social/base_helper"
module Admin::Social::StreamsHelper
  include Social::BaseHelper
  
  def visibility_options(item)
    selected_val = []
    all_groups = fetch_groups 
      
    unless item.new_record?
      stream = item.is_a?(Social::TwitterHandle) ? fetch_default_stream(item) : item
      if stream.accessible.global_access_type?
        selected_val << all_groups.rassoc("#{I18n.t('admin.social.streams.visibility.all')}")[0].to_s
      elsif stream.accessible.group_access_type?
        stream_groups = stream.groups.collect { |g| [g.id, CGI.escapeHTML(g.name)] }
        accessible_groups = stream_groups & all_groups
        selected_val = accessible_groups.map {|group| group[0].to_s }.flatten
      end
    else
      selected_val << all_groups.rassoc("#{I18n.t('admin.social.streams.visibility.all')}")[0].to_s
    end
    
    select_tag :visible_to, options_for_select(all_groups.map {|k, v| [v.html_safe, k.to_s]}, selected_val), { :multiple => true, :class => 'select2-container select2 span10 required', :placeholder => " Select groups" }
  end
  
  def fetch_groups
    all_groups = []
    all_groups.push([0, "#{I18n.t('admin.social.streams.visibility.all')}" ])
    all_groups.concat(Account.current.support_agent_groups_from_cache.collect { |g| [g.id, CGI.escapeHTML(g.name)] })
  end
  
  def fetch_default_stream(handle)
    handle.twitter_streams.select {|stream| stream.default_stream? }.first
  end

  def onclick_strategy(auth_redirect_url)
    "parent.location.href='#{auth_redirect_url}'"
  end

end
