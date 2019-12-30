module Freshcaller
  class Agent < ActiveRecord::Base
    self.table_name =  :freshcaller_agents
    self.primary_key = :id

    belongs_to_account
    belongs_to :agent, class_name: '::Agent'
    has_one :user, through: :agent
    concerned_with :presenter
  end
end
