require 'test_helper'

class Helpdesk::TagTest < ActiveSupport::TestCase
  should_have_many :tag_uses
  should_have_many :tickets, :through => :tag_uses
  should_have_instance_methods :nickname
  should_ensure_length_in_range :name, (1..32) 

  should "Have required contants" do
    assert Helpdesk::Ticket::SORT_FIELDS
    assert Helpdesk::Ticket::SORT_FIELD_OPTIONS
    assert Helpdesk::Ticket::SORT_SQL_BY_KEY
  end

  context "A new tag" do
    setup { @tag = Helpdesk::Tag.new }

    should "return slug as to_param" do
      @tag.expects(:id).times(2).returns(1)
      @tag.expects(:name).returns("Some Kind of Tag.")
      assert_equal '1-some-kind-of-tag-', @tag.to_param
    end

    should "return name when nickname called" do
      @tag.expects(:name).returns(:johndoe)
      assert_equal :johndoe, @tag.nickname
    end
  end

end
