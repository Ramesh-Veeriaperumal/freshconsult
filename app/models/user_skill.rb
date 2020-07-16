class UserSkill < ActiveRecord::Base
  
  primary_key = :id
 
  include Cache::Memcache::Helpdesk::Filters::CustomTicketFilter

  belongs_to_account
  belongs_to :user
  belongs_to :skill, :class_name => 'Admin::Skill'

  before_validation :assign_last_rank, :unless => :rank? 

  validates_presence_of :user
  validates_presence_of :skill
  validates_presence_of :rank # rank is user's skill preference, not the other way
  validate :no_of_skills_per_user, on: :create

  attr_accessor :rank_handled_in_ui, :multiple_skills_added_to_user
  attr_accessible :skill_id, :user_id, :rank, :rank_handled_in_ui,
  :multiple_skills_added_to_user

  before_destroy :decrement_rank_on_lower_items, :unless => :rank_handled_in_ui
  after_commit :sync_skill_based_user_queues

  scope :account_user_scope, lambda { |account_id, user_id| {
    :conditions => ["account_id = ? AND user_id = ?", account_id, user_id]
  }}

  scope :greater_than_rank, lambda { |rank| {
    :conditions => ["rank > ?", rank]
  }}

  def sync_skill_based_user_queues
    if account.skill_based_round_robin_enabled? && (user.agent.nil? || user.agent.available?)#user.agent.nil? - hack for agent destroy
      SBRR::Config::UserSkill.perform_async(:action => _action, :user_id => user_id, 
        :skill_id => skill_id, :multiple_skills_added_to_user => multiple_skills_added_to_user)
    end
  end

  def _action
    [:create, :update, :destroy].find{ |action| transaction_include_action? action }
  end

  private

    def assign_last_rank
      last_user_skill = user.user_skills[-1]
      last_user_skill_rank = (last_user_skill && last_user_skill.rank).to_i 
      self.rank = last_user_skill_rank + 1
    end

    def decrement_rank_on_lower_items #i think we need callbacks instead of update_all - check later
      self.class.account_user_scope(account_id, user_id).greater_than_rank(rank).find_each(:batch_size => 500) do |user_skill|
        decremented_rank = user_skill.rank - 1
        user_skill.update_attributes(rank: decremented_rank)
      end
    end

    def scope_condition
      "account_id = #{account_id} and user_id = #{user_id}"
    end

    def no_of_skills_per_user # to validate bulk skill ids assignment eg: user.user_ids = []
      if user.user_skills.count >= User::MAX_NO_OF_SKILLS_PER_USER
        errors.add(:base, :max_skills_per_user, :max_limit => User::MAX_NO_OF_SKILLS_PER_USER)
      end
    end

end
