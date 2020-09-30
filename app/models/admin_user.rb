# encoding: utf-8
class AdminUser < ActiveRecord::Base
  not_sharded
  self.primary_key = :id
  
  FD_EMAIL_REGEX = /\b[-a-zA-Z0-9.'’&_%+]+[a-zA-Z0-9.-]+@freshdesk\.com\b/
  PASSWORD_REGEX = /^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[#?!@$%^&*-]).{8,}$/

  acts_as_authentic do |c|
    c.session_class = AdminSession
    c.validate :password_validation
    c.validates_format_of_email_field_options :with => FD_EMAIL_REGEX
    c.crypto_provider = Authlogic::CryptoProviders::Sha512
  end

  validates_uniqueness_of :name, :message => "is already in use"
 
  validates_format_of :name, :with => /\A([a-z0-9_]{2,16})\z/i,
    :message => "must be 4 to 16 letters, numbers or underscores and have no spaces"

  ADMIN_ROLES = [
    [:super_admin, "Super Admin", 1],
    [:marketer, "Marketer", 2],
    [:support, "Support", 3]
  ]

  ADMIN_ROLES_OPTIONS = ADMIN_ROLES.map { |i| [i[1], i[2]] }
  ADMIN_ROLES_NAMES_BY_KEY = Hash[*ADMIN_ROLES.map { |i| [i[2], i[1]] }.flatten]
  ADMIN_ROLES_NAMES_BY_ID =Hash[*ADMIN_ROLES.map { |i| [i[2], i[0]] }.flatten]
  ADMIN_ROLES_KEYS_BY_TOKEN = Hash[*ADMIN_ROLES.map { |i| [i[0], i[2]] }.flatten]
  ADMIN_ROLES_KEYS_BY_NAME = Hash[*ADMIN_ROLES.map { |i| [i[1], i[2]] }.flatten]

  attr_accessible :name, :password, :password_confirmation, :email, :role


  def password_validation
    password =~ PASSWORD_REGEX
  end


  #authlogic method to specify idle time before logging out the user.1 day
  def logged_in_timeout
    1440.minutes
  end

  def self.role_list
     ADMIN_ROLES_KEYS_BY_NAME
  end

  def human_role_name
    ADMIN_ROLES_NAMES_BY_KEY[self.role]
  end

  def role_name
    ADMIN_ROLES_NAMES_BY_ID[self.role]
  end

  def super_admin?
    self.role == ADMIN_ROLES_KEYS_BY_TOKEN[:super_admin]
  end

  def marketer?
    self.role == ADMIN_ROLES_KEYS_BY_TOKEN[:admin]
  end

  def support?
    self.role == ADMIN_ROLES_KEYS_BY_TOKEN[:support]
  end

  def has_role?(user_role)
    ADMIN_ROLES_LIST[self.role_name.downcase].include?(user_role.to_s.downcase)
  end


end