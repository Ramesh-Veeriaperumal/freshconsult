class Admin::Skill < ActiveRecord::Base

  primary_key = :id
  
  include Cache::Memcache::Skill

  NOT_OPERATORS = ['is_not', 'does_not_contain', 'not_selected', 'not_in']
  MAX_NO_OF_SKILLS_PER_ACCOUNT = 180

  serialize :filter_data
  
  belongs_to_account
  has_many :user_skills, :order => :rank
  has_many :users, :through => :user_skills, :source => :user, :order => 'user_skills.rank',
            :dependent => :destroy

  scope :trimmed, :select => [:id, :name]

  before_validation :assign_last_position, :unless => :position?

  validates_presence_of :name
  validates_presence_of :position
  validates_presence_of :match_type
  validates_inclusion_of :match_type, :in => %w( any all )
  validates_uniqueness_of :name, :scope => :account_id
  validate :no_of_skills_per_account
  
  after_commit :clear_skills_cache

  attr_accessor :conditions
  accepts_nested_attributes_for :user_skills, :allow_destroy => true
  attr_accessible :name, :description, :match_type, :filter_data, :position, :user_ids, :user_skills_attributes

  class << self

    def map_to ticket 
      account = Account.current
      Time.use_zone(account.time_zone) do
        check_skills account, ticket
      end
    end

    def check_skills account, ticket
      account.skills_from_cache.any? do |skill|
        skill.check_conditions(ticket)
      end
    end

  end

  def check_conditions(ticket)
    if matches?(ticket)
      map_skill(ticket)
    end
  end
  
  def matches?(ticket)
    Rails.logger.debug "Inside SKILL matches? WITH ticket : #{ticket.inspect} conditions : #{conditions.inspect}"
    return true if conditions.blank?
    conditions.send("#{match_type}?") do |c|
      current_evaluate_on = custom_eval(ticket, c.evaluate_on_type)
      current_evaluate_on.present? ? c.matches(current_evaluate_on) : negation_operator?(c.operator)
    end
  end

  def map_skill ticket
    ticket.skill = self
  end

  def conditions
    @conditions ||= filter_data.collect{ |f| Va::Condition.new(f.symbolize_keys, account) }
  end

  private

    #For company being nil, returning true for these operator based conditions
    def negation_operator?(operator)
      Va::Constants::NOT_OPERATORS.include?(operator)
    end

    def custom_eval(evaluate_on, evaluate_on_type)
      case evaluate_on_type
      when "ticket"
        evaluate_on
      when "requester"
        evaluate_on.requester
      when "company"
        evaluate_on.company
      end
    end

    def assign_last_position
      last_skill = account.skills[-2] #last object happens to be the unsaved self
      last_skill_position = (last_skill && last_skill.position).to_i 
      self.position = last_skill_position + 1
    end

    def no_of_skills_per_account
      if account.skills.count >= MAX_NO_OF_SKILLS_PER_ACCOUNT
        errors.add(:base, :max_skills_per_account, :max_limit => MAX_NO_OF_SKILLS_PER_ACCOUNT) 
      end
    end

end
