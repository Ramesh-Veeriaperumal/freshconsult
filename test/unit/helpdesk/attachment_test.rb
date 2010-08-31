require 'test_helper'

class Helpdesk::AttachmentTest < ActiveSupport::TestCase
  should_belong_to :attachable
  should_have_attached_file :content
end
