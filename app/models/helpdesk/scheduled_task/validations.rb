class Helpdesk::ScheduledTask < ActiveRecord::Base
  include HelpdeskReports::Helper::PlanConstraints
  
  validates_inclusion_of :status, :in => STATUS_TOKEN_TO_NAME.keys
  validates_inclusion_of :frequency, :in => STATUS_TOKEN_TO_NAME.keys, :allow_nil => true
  validates_inclusion_of :day_of_frequency, :in => 0..31, :allow_nil => true
  validates_inclusion_of :repeat_frequency, :in => 1..30, :allow_nil => true
  validates_inclusion_of :minute_of_day, :in => 0..1440, :allow_nil => true

  validate :scheduled_reports_constraints, :on => :create, :if => :scheduled_report?
  validate :scheduled_reports_constraints, :on => :update, :if => Proc.new { scheduled_report? && inactive_to_active? }

  validate :scheduled_reports_frequency, :if => :scheduled_report?
  
private

  def scheduled_reports_constraints
    if max_limits_by_user?(:scheduled_report)
      errors.add( :constraints, 
                  I18n.t('helpdesk_reports.scheduled_reports.errors.user_max_limit', 
                  count: max_limit(:scheduled_report, :user)))
    end

    if max_limits_by_account?(:scheduled_report)
      errors.add( :constraints, 
                  I18n.t('helpdesk_reports.scheduled_reports.errors.acc_max_limit', 
                  count: max_limit(:scheduled_report, :account)))
    end
  end

  def scheduled_reports_frequency
    unless allowed_frequencies.include?(frequency)
      errors.add( :constraints,
                  I18n.t('helpdesk_reports.scheduled_reports.errors.invalid_frequency')
                  )
    end
  end

  def allowed_frequencies
    #Includes daily, weekly & monthly
    FREQUENCY_TOKEN_TO_NAME.keys.last(3)
  end

  def inactive_to_active?
    status_was.in?(INACTIVE_STATUS) && !status.in?(INACTIVE_STATUS)
  end
  
end