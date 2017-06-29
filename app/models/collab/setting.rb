# encoding: utf-8
class Collab::Setting < ActiveRecord::Base
  
  self.table_name = :collab_settings
  self.primary_key = :id

  belongs_to_account
end