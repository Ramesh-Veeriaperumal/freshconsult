class PopulateAuthorityColumnsInUser < ActiveRecord::Migration
  shard :none
  def self.up
    default_roles = [
          [ "Account Administrator",
             "Has complete control over the help desk including access to Account
              or Billing related information, and receives Invoices.",
            Helpdesk::Roles::ACCOUNT_ADMINISTRATOR ],
          
          [ "Administrator",
            "Can configure all features through the Admin tab, but is restricted
             from viewing Account or Billing related information.",
             Helpdesk::Roles::ADMINISTRATOR ],
          
          [ "Supervisor",
            "Can perform all agent related activities and access reports,
             but cannot access or change configurations in the Admin tab.",
             Helpdesk::Roles::SUPERVISOR ],
          
          [ "Agent",
            "Can log, view, reply, update and resolve tickets and manage contacts.",
            Helpdesk::Roles::AGENT ],
          
          [ "Restricted Agent",
            "Can log, view, reply, update and resolve tickets, but cannot view or edit contacts.",
             Helpdesk::Roles::RESTRICTED_AGENT ]
        ]
    
    roles_mapping = {
      :account_admin => 0,
      :admin =>         1,
      :supervisor =>    2,
      :poweruser =>     3
    }
    
    default_roles.each do |role|
      role[2] = Role.privileges_mask(role[2]).to_s
    end
    
    # roles
    # 3373 rows < 0.1ms
    default_roles.each do |role|
      execute( %(INSERT INTO roles (name, privileges, description, default_role, account_id, created_at, updated_at)
                 SELECT '#{role[0]}', '#{role[2]}', '#{role[1]}', true, id, now(), now()
                 FROM accounts) ) 
    end
    
    # what should happen in self.down?
    
    # 1,00,000 rows ~ 3.88 sec
    # execute(%(INSERT INTO user_roles (user_id, role_id, account_id, created_at, updated_at)
    #       SELECT id, (SELECT id FROM roles WHERE name = '#{DEFAULT_ROLES[ROLES_MAPPING[role[0]]][0]}' AND 
    #       roles.account_id = users.account_id),
    #       account_id, now(), now()
    #       FROM users
    #       WHERE user_role = #{role[2]}))
    
    
    Account.find_in_batches do |accounts|
      accounts.each do |account|
        # alter table taking 37.24 sec helpdesk_agent > 1,00,000
        # 3,373 0.49 sec
        execute( %(UPDATE users SET helpdesk_agent = true
          WHERE user_role in (1,2,4,6) AND account_id = '#{account.id}') )
    
        # 1,00,000 ~ 10 sec
        # after change ~ 2.3 sec
        User::USER_ROLES.each do |role|
          if roles_mapping[role[0]]
            # if not poweruser or client_manager
            if [1,4,6].include?(role[2])
              execute( %(UPDATE users 
                     SET users.privileges = '#{default_roles[roles_mapping[role[0]]][2]}'
                     WHERE user_role = #{role[2]} AND
                     account_id = #{account.id} AND
                     deleted = 0) )
                     
               execute( %(INSERT INTO user_roles (user_id, role_id, account_id)
                          SELECT users.id, roles.id, users.account_id
                          FROM users, roles
                          WHERE users.account_id = #{account.id} AND
                           users.user_role = #{role[2]} AND
                           roles.name = '#{default_roles[roles_mapping[role[0]]][0]}' AND
                           roles.account_id = users.account_id AND
                           users.deleted = 0)
                      )
                 
            elsif role[2] == 2
              # for agents with global access
              execute( %(UPDATE users, agents 
                     SET users.privileges = '#{default_roles[3][2]}'
                     WHERE users.account_id = #{account.id} AND
                     users.user_role = #{role[2]} AND
                     agents.user_id = users.id AND agents.account_id = users.account_id AND 
                     agents.ticket_permission = 1 AND
                     users.deleted = 0) )
                     
               execute( %(INSERT INTO user_roles (user_id, role_id, account_id)
                          SELECT users.id, roles.id, users.account_id
                          FROM users, agents, roles
                          WHERE users.account_id = #{account.id} AND
                           users.user_role = #{role[2]} AND
                           agents.user_id = users.id AND agents.account_id = users.account_id AND 
                           agents.ticket_permission = 1 AND
                           roles.name = 'Agent' AND
                           roles.account_id = users.account_id AND
                           users.deleted = 0) )
          
              # for agents with restricted and group access       
              execute( %(UPDATE users, agents 
                       SET users.privileges = '#{default_roles[4][2]}'
                       WHERE users.account_id = #{account.id} AND
                       users.user_role = #{role[2]} AND
                       agents.user_id = users.id AND agents.account_id = users.account_id AND 
                       agents.ticket_permission IN (2,3) AND
                       users.deleted = 0) )    
                       
               # for agents with restricted and group access    
               execute( %(INSERT INTO user_roles (user_id, role_id, account_id)
                          SELECT users.id, roles.id, users.account_id
                          FROM users, agents, roles
                          WHERE users.account_id = #{account.id} AND
                           users.user_role = #{role[2]} AND
                           agents.user_id = users.id AND agents.account_id = users.account_id AND 
                           agents.ticket_permission IN (2,3) AND
                           roles.name = 'Restricted Agent' AND
                           roles.account_id = users.account_id AND
                           users.deleted = 0) 
                      )   
            end
          end        
        end
    
        # privileges for client manager
        client_manager = Role.privileges_mask([:client_manager]).to_s
        execute( %(UPDATE users
               SET users.privileges = '#{client_manager}'
               WHERE users.user_role = 5 AND
               account_id = #{account.id} AND
               deleted = 0) )
             
        # Once all migrations for that account has been run then set a redis flag
        # account.add_to_set('authrority_migrated', [account.id])
        $redis_others.sadd('authority_migrated', account.id)
      end
    end
  end

  def self.down
    $redis_others.del('authority_migrated')
  end
end
