class Social::TicketRule < ActiveRecord::Base

  set_table_name "social_ticket_rules"

  belongs_to_account # @ARV@ TODO must check if its okay to have a table without account_id

  belongs_to :stream,
    :foreign_key => :stream_id,
    :class_name => 'Social::Stream'

  serialize :filter_data, Hash
  serialize :action_data, Hash


  def apply(feed)
    #For now, check for includes alone
    return check_includes(feed)
  end

  private
    def check_includes(feed)
      includes = filter_data[:includes]
      includes.each do |keyword|
        return true if feed.downcase.include?(keyword.downcase)
      end
      return false
    end
end
