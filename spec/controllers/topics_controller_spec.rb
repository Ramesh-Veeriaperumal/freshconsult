require 'spec_helper'

describe TopicsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @category = create_test_category
    @forum = create_test_forum(@category)
    @agent = add_test_agent(@account)
  end

  before(:each) do
    log_in(@agent)
  end

  it "should redirect to new discussions topic page on 'new'" do
    get :new, :category_id => @category.id, :forum_id => @forum.id
    response.should redirect_to new_discussions_topic_path
  end

  it "should redirect to discussions topic show page on 'show'" do
    topic = create_test_topic(@forum)
    get :show, :category_id => @category.id, :forum_id => @forum.id, :id => topic.id
    response.should redirect_to discussions_topic_path(topic)
  end

  it "should redirect to edit discussions topic edit page on 'edit'" do
    topic = create_test_topic(@forum)
    create_test_post(topic)
    get :edit, :category_id => @category.id, :forum_id => @forum.id, :id => topic.id
    response.should redirect_to edit_discussions_topic_path(topic)
  end

  it "should render wrong portal page for an invalid request" do
    topic = create_test_topic(@forum)
    controller.stubs(:main_portal?).returns(false)
    get :show, :category_id => @category.id+10000, :forum_id => @forum.id, :id => topic.id
    response.should render_template("errors/_error_page")
    controller.class.any_instance.unstub(:main_portal?)
  end

  # it "should redirect to discussions topic page on 'index'" do
  #   get :index, :category_id => @category.id, :forum_id => @forum.id
  #   response.should redirect_to '/discussions'
  # end
end
