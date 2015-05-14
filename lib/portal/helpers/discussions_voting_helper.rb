module Portal::Helpers::DiscussionsVotingHelper

  VOTE_BUTTON = {
    true => {
      :status => 'voted',
      :title => 'portal.post_vote.upvoted',
      :icon => 'icon-vote-unlike'
    },
    false => {
      :status => 'unvoted',
      :title => 'portal.post_vote.upvote',
      :icon => 'icon-vote-like'
    }
  }

  def upvoting object
    output = ""
    output << upvoting_button(object.source)
    output << upvoting_count(object.source)
    output.prepend("<hr>") unless output.empty?
    output.html_safe
  end

  def post_vote_button post
    output = ""
    output << "<div class='btn-group' id='post-#{post.id}-vote-toolbar'>"
    output << upvoting(post) 
    output << "</div>"
    output.html_safe
  end

  def upvoting_button object
    return "" if object.blank? or User.current.blank? or object.user_id == User.current.id
    btn_data = VOTE_BUTTON[object.voted_by_user?(User.current)]
    link_to(
        %(<span class="#{btn_data[:icon]}"></span>).html_safe, like_url(object),
        :class => "#{btn_data[:status]} vote-like-btn",
        :id => "#{object.class.to_s.downcase}-#{object.id}-vote-up-button",
        "data-remote" => true,
        "data-toggle" => "tooltip",
        "data-no-loading" => true,
        :title => t(btn_data[:title]),
        "data-response-type" => "script",
        "data-method" => "put"
    ).html_safe
  end
    # used by both topic and post
  def upvoting_count object
    return "" if object.user_votes == 0
    output = %( <span class="vote-bar"> )
    if object.voted_by_user?(User.current)
      output << vote_count_prefix(object)
      output << vote_count_link(object) if object.user_votes > 1
    else
      output << vote_count_link(object)
    end
    output << vote_count_suffix(object)
    output << %(</span>)
    output.html_safe
  end


  def vote_count_prefix object
    I18n.t("portal.vote.you", :count => object.user_votes)
  end
  
  def vote_count_middle object
    votes_to_show = votes_to_display(object)
    translation = object.voted_by_user?(User.current) ? 'more' : 'people'
    I18n.t("portal.vote.#{translation}", :count => votes_to_display(object))
  end

  def user_upvote_list_title object
    return I18n.t('portal.topic_vote.user_upvote_list_title') if object.is_a?(Post)
    I18n.t("portal.topic_vote.#{object.forum.type_symbol}_users_voted_title")
  end

  def vote_count_suffix object
    type_symbol = object.is_a?(Topic) ? object.forum.type_symbol: "like"
    " " + I18n.t("portal.#{object.class.to_s.downcase}_vote.#{type_symbol}", :count => object.user_votes)
  end

  def vote_count_link object
    count_text = vote_count_middle(object)
    data_target = object.is_a?(Post) ? "#users-voted-post-#{object.id}" : "#users-voted" 
    output = ""
    if User.current.present?
      output << "<span title='#{populate_vote_list_content(object)}' 
                      data-html='true' 
                      data-placement='bottom' 
                      data-toggle='tooltip'>"
      output <<   link_to(count_text,
                          users_vote_list_url(object),
                          :rel => "freshdialog",
                          "data-title" => user_upvote_list_title(object),
                          :id => "#{object.class.to_s.downcase}-#{object.id}-vote-count",
                          :class => "vote-count",
                          "data-html" => "true",
                          "data-target" => "#{data_target}",
                          "data-template-footer" => "",
                          "data-width" => "300"
                        )
      output << "</span>"
    
    else
      output << count_text
    end 
    output.html_safe
  end

  def votes_to_display object
    if  User.current.present? and object.voted_by_user?(User.current) 
      object.user_votes - 1 
    else
      object.user_votes
    end
  end

  def populate_vote_list_content object
    return "" unless User.current.present?
    output = []
    voters = object.voters.all(:limit => 6).reject { |user| user.id == User.current.id }.collect(&:name)
    voters.first(5).each do |name|
      output << "<div>#{h(name)}</div>"
    end
    output << "..." if object.user_votes > 5
    output.join.html_safe
  end

  def vote_up_list object
    return "" unless User.current.present?
    output = object.voters.collect(&:name)
    output.map! { |name| h(name)  }
    output.join("<br>").html_safe
  end


  def like_url object
    return object.is_a?(Topic) ? "/support/discussions/topics/#{object.id}/like" : 
                                  "/support/discussions/topics/#{object.topic.id}/posts/#{object.id}/like"  
  end
  
  def users_vote_list_url object
    return object.is_a?(Topic) ? "/support/discussions/topics/#{object.id}/users_voted" : 
                                  "/support/discussions/topics/#{object.topic.id}/posts/#{object.id}/users_voted"
  end

end