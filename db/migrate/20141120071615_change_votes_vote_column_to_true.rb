class ChangeVotesVoteColumnToTrue < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    # acts_as_voteable votes_for method counts votes set in vote column as true and votes_against method counts votes set in vote column as false
    # rectifying reverse logic currently used for voteable_type = Topic
    Vote.find_in_batches(:batch_size => 500, :conditions => { :voteable_type => 'Topic', :vote => false}) do |votes|
      votes.each { |vote| vote.update_attributes(:vote => true) }
    end
  end

  def down
  end
end

