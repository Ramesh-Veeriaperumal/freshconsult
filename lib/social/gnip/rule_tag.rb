class Social::Gnip::RuleTag

  include Social::Gnip::Constants

  attr_accessor :handle_id, :account_id

  def initialize(tag)
    tag_elements = tag.split(DELIMITER[:tag_elements])

    @handle_id = tag_elements[0].to_i
    @account_id = tag_elements[1].to_i
  end
  

  def self.handle_ids(tag)
    tag_array = tag.split(DELIMITER[:tags])
    twitter_handle_ids = tag_array.inject([]) do |ids,tag|
        ids << tag.split(DELIMITER[:tag_elements]).first
        ids
    end
    twitter_handle_ids
  end
  

  def self.update(old_tag, twt_handle)
    rule_tag = build(twt_handle.id,twt_handle.account_id)
    updated_tag = "#{old_tag}#{DELIMITER[:tags]}#{rule_tag}"
  end
  

  def self.build(handle_id, account_id)
    "#{handle_id}#{DELIMITER[:tag_elements]}#{account_id}"
  end
end
