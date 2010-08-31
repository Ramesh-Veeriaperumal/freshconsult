require 'test_helper'

class Helpdesk::ArticleGuideTest < ActiveSupport::TestCase
  should_belong_to :articles, :guides
end
