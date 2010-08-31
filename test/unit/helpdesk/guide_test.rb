require 'test_helper'

class Helpdesk::GuideTest < ActiveSupport::TestCase
  should_have_many :article_guides
  should_have_many :articles, :through => :article_guides

  should_have_named_scope :most_used_first
  should_have_named_scope :alphabetical
  should_have_named_scope :display_order
  should_have_named_scope :visible

  should_have_instance_methods :nickname
  should_validate_presence_of :name
  should_ensure_length_in_range :name, (2..240) 

  context "a new guide" do
    setup { @guide = Helpdesk::Guide.new }

    should "return slug as to_param" do
      @guide.expects(:id).times(2).returns(1)
      @guide.expects(:name).returns("Some Kind of ? Guide.")
      assert_equal '1-some-kind-of-guide-', @guide.to_param
    end

    should "return name when nickname called" do
      @guide.expects(:name).returns(:guidename)
      assert_equal :guidename, @guide.nickname
    end
  end
end
