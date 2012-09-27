class SubscriptionDiscount < ActiveRecord::Base
  include Comparable
  class ComparableError < StandardError; end
  
  validates_numericality_of :amount
  validates_presence_of :code, :name
  
  before_save :check_percentage
  belongs_to :subscription_plan, :foreign_key => :plan_id

  attr_accessor :calculated_amount

  def available?
    return false if self.start_on && self.start_on > Time.now.to_date
    return false if self.end_on && self.end_on < Time.now.to_date
    true
  end

  def calculate(subtotal)
    return 0 unless subtotal.to_i > 0
    return 0 unless self.available?
    self.calculated_amount = if self.percent
      (self.amount * subtotal).round.to_f
    else
      self.amount > subtotal ? subtotal : self.amount
    end
  end

  def <=>(other)
    return 1 if other.nil?
    raise ComparableError, "Can't compare discounts that are calcuated differently" if percent != other.percent
    amount <=> other.amount
  end

  def has_free_agents?
    (free_agents) and (free_agents > 0)
  end

  def can_be_applied_to?(plan)
    subscription_plan.eql?(plan) and available?
  end

  def expires?
    (end_on) or (life_time and life_time > 0)
  end

  def life_time_discount?
    life_time and life_time > 0
  end

  def calculate_discount_expiry
    return end_on if end_on and self.end_on > Time.now.to_date
    return Time.now.advance(:months => life_time) if life_time_discount?
  end

  protected

    def check_percentage
      if self.amount > 1 and self.percent
        self.amount = self.amount / 100
      end
    end

end
