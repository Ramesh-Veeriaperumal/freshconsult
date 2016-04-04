module Community::MonitorshipHelper

  include Rails.application.routes.url_helpers
 
  def follower_button object, status
    content_tag :span, '', {
      :class => "add_follower_icon forum_follow_icon tooltip #{status}",
      :id => 'toggle_monitorship_status',
      :"data-current-user" => User.current.id,
      :"data-hotkey" => shortcut("discussions.toggle_following"),
      :"data-following" => status.present?,
      :"data-remote-url" => "/discussions/#{object.class.name.downcase}/#{object.id}/subscriptions/",
      :title => t('monitorships.follow_title')
    }
  end

  def monitor_container object
    output = ""
    output << "<div class='followers_tooltip hide #{additional_style(object)}' id='new_follower_page'"
    output << "rel='remote-load' data-url= \"#{monitorship_url(object)}\" data-load-unique='true'>"
    output << "<span class='arrow-top'></span></div>"
    output.html_safe
  end

  def follower_content object
    output = ""
    output << follower_header(object)
    output << follower_select_list(object)
    output.html_safe
  end

  def monitorship_url object
    scope = object.class.to_s.downcase
    view_monitorship_path(:object => scope, :id => object.id)
  end

  def follower_header object
    scope = object.class.to_s.downcase
    output = ""
    output << "<span class='arrow-top #{arrow_icon_direction(object)}'></span>"
    output << "<span class='follower-close'>&times</span>"

    output << "<div class='follower_label'><div>"
    output << t("#{scope}.follower.title")

    if object.monitors.count > 0
      output << "<span class='follower_count'> (#{@parent.monitors.technicians.count})</span>"
    end
    output << "</div><div class='follower_text'>"
    output <<  t("#{scope}.follower.description")
    output << "</div></div>"
    output.html_safe
  end

  def follower_select_list object
    addtional_style =  object.is_a?(Forum) ? 'select-follower' : ''
    output = "<div id='addfollower'><div class='select_agents #{addtional_style}'>"
    output << '<span class="rounded-add-icon"></span>'
    output << select_tag( :ids, 
                          options_for_select(unsubscribed_agent_list(object).map {|k, v| [v, k.to_s]}), { 
                          :multiple => true, 
                          :class => "select2 follower_input",
                          "data-placeholder" => t('monitorships.pick_agents')
                        })
    output << "</div></div>"
    output.html_safe
  end

  def order_followers object
    # Shows current user first in follower's list
    followers = object.monitors.technicians.to_a
    if followers.map(&:id).include? User.current.id
      followers.insert(0, followers.delete_at(followers.index{ |l| l.id==User.current.id }))
    end
    followers
  end
  
  def unsubscribed_agent_list(object)
    agents = object.unsubscribed_agents
    if agents.map(&:user_id).include? User.current.id
      agents.insert(0, agents.delete_at(agents.index{ |agent| agent.user_id==User.current.id }))
    end
    agents.reject!{ |agent| !agent.user.privilege?(:view_forums)}
    agents.collect do |agent|
      [agent.user_id, (agent.user_id == User.current.id) ? t("monitorships.me") : agent.user.name]
    end
  end

  def followers_count forum
    output = ""
    output << %(<li class="followers-list list-inline">)
    output << followers_link(forum)
    output << %(</li>)
    output.html_safe
  end

  def followers_link forum
    count = forum.monitors.count
    return "" unless count > 0
    link_to(t('forum_shared.followers', :count => count), 
                         followers_discussions_forum_path(forum),
                         :class => 'forum-followers-list', 
                         'data-target'=> '#forum-followers',
                         :rel => 'freshdialog', 
                         'data-width' => '300', 'data-template-footer' => '', 
                         :title => t('forum_shared.followers_title', :count => count))
  end


  def topic_followers topic
    count = topic.monitors.count
    output = render(:partial => "discussions/topics/widgets/user_list", :locals => {
                :title => t("discussions.topics.title_meta.following", :count => count),
                :count => count,
                :user_list => topic.monitors,
                :modal_target => "following_users_all",
                :href => discussions_topic_component_path(:id => topic.id, :name => 'following_users')
              })
    escape_javascript(output)
  end

  def refresh_followers object
    action = ""
    if object.is_a?(Forum)
      action <<  "jQuery('.followers-list').replaceWith('#{followers_count(object)}');"
    else
      action << "jQuery('#widget-following_users_all').replaceWith('#{topic_followers(object)}');"
    end
    action
  end

  def highlight_follower_button object
    following = object.monitors.map(&:id).include?(User.current.id)
    action = "jQuery('.forum_follow_icon').toggleClass('active', #{following});"
    action << "jQuery('#toggle_monitorship_status').data('following',#{following});"
    action
  end

  def additional_style object
    if object.is_a?(Forum)
      'forum-follower'
    elsif object.is_a?(Topic) and !User.current.privilege?(:edit_topic)
      'topic-follower-right'
    end
  end
  
  def arrow_icon_direction object
    'arrow-top-right' if object.is_a?(Topic) and !User.current.privilege?(:edit_topic)    
  end

end