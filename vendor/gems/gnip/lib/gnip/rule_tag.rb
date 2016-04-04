class Gnip::RuleTag

  include Gnip::Constants

  attr_accessor :stream_id, :account_id

  def initialize(tag)
    tag_elements = tag.split(DELIMITER[:tag_elements])

    @stream_id = tag_elements[0]
    @account_id = tag_elements[1]
  end
end