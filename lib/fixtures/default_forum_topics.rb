class Fixtures::DefaultForumTopics
  include ActionView::Helpers::TextHelper

  attr_accessor :account, :forum_content

  def create
    create_topics
  end

  private

  def initialize
    @forum_content = I18n.t("discussions.forums.default_forum").map{ |key| key.symbolize_keys}
  end

  def create_topics
    DEFAULT_FORUM_DATA.each do |topic|
      topic_user = create_user(topic[:email],topic[:name])

      current_topic = topic_user.topics.create(
        forum: account.forums.find_by_name(topic[:category]),
        title: forum_content[topic[:data]][:subject],
        hits: topic[:views],
        sticky: topic[:sticky],
        user_votes: topic[:likes],
        stamp_type: topic[:status],
        locked: true
      )
    
      create_post(current_topic,topic_user,forum_content[topic[:data]][:content])

      topic[:replies].each do | reply | 
        post_user = create_user(reply[:email], reply[:name])
        create_post(current_topic, post_user, forum_content[topic[:data]][:replies][reply[:data]])
      end
    end
  end

  def account
    @account ||= Account.current
  end

  def create_user(user_email,user_name)
    user = account.users.find_by_email(user_email)
    return user if user.present?

    user = account.users.create(
      email: user_email,
      name: user_name
      )
  end

  def create_post(topic,user,data)
    topic.posts.create(
      user: user, 
      body_html: simple_format(data)
    )
  end

end