# A big thanks to http://blog.arkency.com/2014/05/mastering-rails-validations-objectify/ !!!!
class TicketValidator < SimpleDelegator
  include ActiveModel::Validations

  validates :group, presence: true, if: -> { group_id  }
  validates :responder, presence: true, if: -> { responder_id }
  validates :email_config, presence: true, if: -> { email_config_id }
  validates :product, presence: true, if: -> { product_id && email_config_id.blank?  }, on: :create
  validates :product, presence: true, if: -> { product_id }, on: :update
  validate :responder_belongs_to_group?, if: -> { group_id && responder_id && errors[:responder].blank? && errors[:group].blank? }
  validate :user_blocked?, if: -> { errors[:requester].blank? && requester_id }

  def user_blocked?
    errors.add(:requester_id, 'user_blocked') if requester && requester.blocked?
  end

  def responder_belongs_to_group?
    belongs_to_group = Account.current.agent_groups.exists?(group_id: group_id, user_id: responder_id)
    errors.add(:responder_id, 'not_part_of_group') unless belongs_to_group
  end
end
