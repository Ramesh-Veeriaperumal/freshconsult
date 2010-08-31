require 'test_helper'

class Helpdesk::ArticleTest < ActiveSupport::TestCase
  should_belong_to :user
  should_have_many :article_guides, :attachments
  should_have_many :guides, :through => :article_guides
  should_not_allow_mass_assignment_of :guides, :attachments
  should_have_named_scope :display_order
  should_have_named_scope :visible
  should_have_class_methods :search
  should_have_instance_methods :nickname
  should_validate_presence_of :title, :body, :user_id
  should_ensure_length_in_range :title, (3..240) 

  should_validate_numericality_of :user_id

  should "Have required contants" do
    assert Helpdesk::Article::SEARCH_FIELDS
    assert Helpdesk::Article::SEARCH_FIELD_OPTIONS
    assert Helpdesk::Article::SORT_FIELDS
    assert Helpdesk::Article::SORT_FIELD_OPTIONS
    assert Helpdesk::Article::SORT_SQL_BY_KEY
  end

  context "A new article record" do
    setup { @article = Helpdesk::Article.new }

    should "return title when nickname called" do
      @article.expects(:title).returns("xxx")
      assert_equal("xxx", @article.nickname)
    end


    should "search by title and body" do
      [:title, :body].each do |f|
        Helpdesk::Article.expects(:scoped).with(:conditions => ["#{f} like ?", "%x%"]).returns(f)
        assert_equal Helpdesk::Article.search(Helpdesk::Article, f, 'x'), f
      end
    end

  end

end
