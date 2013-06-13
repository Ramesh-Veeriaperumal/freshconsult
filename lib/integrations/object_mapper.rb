class Integrations::ObjectMapper
  include Helpdesk::Ticketfields::TicketStatus

  def map_it(account_id, mapper_name, data, convertion_type=:theirs_to_ours, stages = [:fetch, :map, :update])
    Rails.logger.debug "map_it #{mapper_name}, data #{data}, convertion_type: #{convertion_type}, stages: #{stages}"
    mapper_config = Integrations::ObjectMapper::clone(MAPPER_CONFIGURATIONS[mapper_name.to_sym]) || {}
    if data.respond_to?(:account_id)
      data.account_id = account_id
    elsif data.is_a? Hash
      data["account_id"] = account_id
    end
    data_hash = {:input => data}
    stages.each {|s| 
      config = mapper_config[s]
      self.send(s, data_hash, config, convertion_type) unless config.blank?
      Rails.logger.debug "=========== After #{s} for #{mapper_name}: data_hash #{data_hash.inspect} =========="
    }
    data_hash[:to_entity]
  end

  private
    def fetch(data_hash, fetch_config, convertion_type)
      #Fetching
      ours_fetch_config = fetch_config[:ours]
      theirs_fetch_config = fetch_config[:theirs]
      input = data_hash[:input]

      ours_entity = invoke_handler(ours_fetch_config[:handler], input, ours_fetch_config)
      theirs_entity = theirs_fetch_config.blank? ? input : invoke_handler(theirs_fetch_config[:handler], input, theirs_fetch_config)
      if convertion_type == :theirs_to_ours
        data_hash[:from_entity] = theirs_entity
        data_hash[:to_entity] = ours_entity
      else
        data_hash[:from_entity] = ours_entity
        data_hash[:to_entity] = theirs_entity
      end
    end

    def map(data_hash, map_configs, convertion_type)
      #Mapping
      from_entity = data_hash[:from_entity]
      to_entity = data_hash[:to_entity]
      from_entity = data_hash[:input] if from_entity.blank?
      map_configs.each {|map_config|
        ftt = convertion_type.to_s.split("_to_")
        from_meth = map_config[ftt[0].to_sym]
        to_meth = map_config[ftt[1].to_sym]
        convertion_config = map_config["#{convertion_type}".to_sym]
        set_data = from_entity
        if convertion_config.blank?
          unless from_meth.blank?
            if from_entity.class == Hash
              meths = from_meth.split(".")
              meths.each{|m|
                set_data = set_data[m]
              }
            else
              set_data = from_entity.send(from_meth)
            end
          end
        else
          handler = convertion_config[:handler] || :template_convert
          set_data = invoke_handler(handler, set_data, convertion_config)
        end

        Rails.logger.debug  "ObjectMapper::map to_entity #{to_entity.inspect}, to_meth #{to_meth}, set_data #{set_data.inspect}"
        if to_entity.class == Hash
          to_entity[to_meth] = set_data
        elsif !to_meth.nil? and to_entity.respond_to?(to_meth)
          to_entity.send(to_meth+"=", set_data)
        else
          data_hash[:to_entity] = set_data
        end
      }
    end

    def update(data_hash, update_config, convertion_type)
      #Updating
      to_entity = data_hash[:to_entity]
      return if to_entity.blank?
      convertion_handler = update_config["#{convertion_type}_handler".to_sym]
      Rails.logger.debug "to_entity #{to_entity.inspect} convertion_handler #{convertion_handler}"
      invoke_handler(convertion_handler, to_entity, update_config)
    end

    def invoke_handler(handler_name, data, config)
      ours_handler_config = HANDLERS[handler_name]
      ours_handler = ours_handler_config[:clazz].constantize.new
      ours_handler.send(ours_handler_config[:method], data, config)
    end

    def self.clone(obj)
      Marshal.load(Marshal.dump(obj))
    end

  generic_config = {
        :fetch => {:ours => {
            :handler=>:db_fetch,
            :entity=>Helpdesk::Note,
            :create_if_empty=>true
          }
        },
        :map=>[
          {:ours=>"note_body", :theirs_to_ours=>{:handler=>:db_fetch, :create_if_empty=>true, :entity=>Helpdesk::NoteBody,
                          :create_params => {:body => "JIRA comment {{notification_cause}} # {{comment.id}}:\n {{comment.body}}\n", 
                          :account_id => "{{account_id}}"}}}, 
          {:ours=>"user", :theirs_to_ours=>{:handler=>:db_fetch, :use_if_empty=>"account_admin", :entity=>User, :using=>{:conditions=>["email=?", "{{comment.author.emailAddress}}"]}}},

          {:ours=>"source", :theirs_to_ours=>{:handler=>:static_value, :value=>Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"]}},
          {:ours=>"private", :theirs_to_ours=>{:handler=>:static_value, :value=>true}},
          {:ours=>"notable", :theirs_to_ours=>{:handler=>:db_fetch, :entity=>Helpdesk::Ticket, 
                        :using=>{:select=>"helpdesk_tickets.*", :joins=>"INNER JOIN integrated_resources ON integrated_resources.local_integratable_id=helpdesk_tickets.id", 
                        :conditions=>["integrated_resources.remote_integratable_id=?", "{{issue.key}}"]}}},
          {:ours=>"account_id", :theirs_to_ours=>{:value=>"{{account_id}}"}},
          {:ours=>"disable_observer", :theirs_to_ours=>{:handler=>:static_value, :value=>true}}
        ], 
        :update=>{:theirs_to_ours_handler=>:db_save}
      }
  generic_config_external_notes = {
        :fetch => {:ours =>{
           :handler=>:db_fetch,
           :entity=>Helpdesk::ExternalNote,
           :using=>{:select=>"helpdesk_external_notes.*",:conditions=>["note_id=?", "{{note_id}}"]},
           :create_if_empty=>true 
          }
        },
        :map=>[
          {:ours=>"external_id",:theirs_to_ours=>{:value=>"{{comment.id}}"}},
          {:ours=>"note_id",:theirs_to_ours=>{:value=>"{{note_id}}"}},
          {:ours=>"installed_application_id",:theirs_to_ours=>{:value=>"{{installed_application_id}}"}},
          {:ours=>"account_id", :theirs_to_ours=>{:value=>"{{account_id}}"}}
        ],
        :update=>{:theirs_to_ours_handler=>:db_save}
  }
  generic_config[:fetch][:ours][:using] = {:select=>"helpdesk_notes.*",
                                           :joins=>"INNER JOIN helpdesk_external_notes ON helpdesk_external_notes.note_id=helpdesk_notes.id and helpdesk_external_notes.account_id = helpdesk_notes.account_id", 
                                           :conditions=>["helpdesk_external_notes.external_id=?", "{{comment.id}}"]}
  PRIVATE_NOTE_CONFIG = clone(generic_config)
  # PRIVATE_NOTE_CONFIG[:map].push({:ours=>"body_html",:theirs_to_ours=> {:value => "<div>JIRA comment {{notification_cause}} # {{comment.id}}:<br/> {{comment.body}} <br/></div>"}})
  PRIVATE_NOTE_CONFIG[:map].push({:ours=>"to_emails",:theirs_to_ours=> {:handler=>:db_fetch, :entity=>User, :data_type => "String",:field_type => "email", 
                         :using=>{:select=>"users.email",
                                  :joins=>"INNER JOIN helpdesk_tickets INNER JOIN integrated_resources ON integrated_resources.local_integratable_id=helpdesk_tickets.id and  helpdesk_tickets.responder_id = users.id 
                                  and users.account_id = helpdesk_tickets.account_id",
                                  :conditions=>["integrated_resources.remote_integratable_id=?", "{{issue.key}}"]}}})
  EXTERNAL_NOTE_CONFIG = clone(generic_config_external_notes)
  STATUS_AS_PRIVATE_NOTE_CONFIG = clone(generic_config)
  STATUS_AS_PRIVATE_NOTE_CONFIG[:map][0][:theirs_to_ours][:create_params] = {:body => "JIRA issue status changed to {{issue.fields.status.name}}.\n"}
  STATUS_AS_PRIVATE_NOTE_CONFIG[:map][1][:theirs_to_ours][:using] = {:conditions=>["email=?", "{{user.emailAddress}}"]}

  STATUS_AS_PRIVATE_NOTE_CONFIG[:map].push({:ours=>"to_emails",:theirs_to_ours=> {:handler=>:db_fetch, :entity=>User, :data_type => "String",:field_type => "email",
                         :using=>{:select=>"users.email",
                                  :joins=>"INNER JOIN helpdesk_tickets INNER JOIN integrated_resources ON integrated_resources.local_integratable_id=helpdesk_tickets.id and  helpdesk_tickets.responder_id = users.id 
                                  and users.account_id = helpdesk_tickets.account_id",
                                  :conditions=>["integrated_resources.remote_integratable_id=?", "{{issue.key}}"]}}})
  PUBLIC_NOTE_CONFIG = clone(generic_config)
  PUBLIC_NOTE_CONFIG[:map][3][:theirs_to_ours][:value] = false
  # PUBLIC_NOTE_CONFIG[:map].push({:ours=>"body_html",:theirs_to_ours=> {:value => "<div>JIRA comment {{notification_cause}} # {{comment.id}}:<br/> {{comment.body}} <br/></div>"}})
  STATUS_AS_PUBLIC_NOTE_CONFIG = clone(generic_config)
  STATUS_AS_PUBLIC_NOTE_CONFIG[:map][0][:theirs_to_ours][:create_params] = {:body => "JIRA issue status changed to {{issue.fields.status.name}}.\n"}
  STATUS_AS_PUBLIC_NOTE_CONFIG[:map][1][:theirs_to_ours][:using] = {:conditions=>["email=?", "{{user.emailAddress}}"]}
  STATUS_AS_PUBLIC_NOTE_CONFIG[:map][3][:theirs_to_ours][:value] = false

  REPLY_CONFIG = clone(generic_config)
  REPLY_CONFIG[:map][2][:theirs_to_ours][:value] = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"] #source
  REPLY_CONFIG[:map][3][:theirs_to_ours][:value] = false #private
  REPLY_CONFIG[:map][0][:theirs_to_ours][:create_params][:full_text] = "JIRA comment {{notification_cause}} # {{comment.id}}:\n {{comment.body}}\n"
  
  # REPLY_CONFIG[:map].push({:ours=>"body_html",:theirs_to_ours=> {:value => "<div>JIRA comment {{notification_cause}} # {{comment.id}}:<br/> {{comment.body}} <br/></div>"}})
  
  MAPPER_CONFIGURATIONS = {
      :add_private_note_in_fd => PRIVATE_NOTE_CONFIG,
      :add_public_note_in_fd => PUBLIC_NOTE_CONFIG,
      :add_helpdesk_external_note_in_fd => EXTERNAL_NOTE_CONFIG,
      :add_status_as_private_note_in_fd => STATUS_AS_PRIVATE_NOTE_CONFIG,
      :add_status_as_public_note_in_fd => STATUS_AS_PUBLIC_NOTE_CONFIG,
      :send_reply_in_fd => REPLY_CONFIG,
      :update_status_in_fd => {
        :fetch => {:ours => {
            :handler=>:db_fetch,
            :entity=>Helpdesk::Ticket,
            :using=>{:select=>"helpdesk_tickets.*", :joins=>"INNER JOIN integrated_resources ON integrated_resources.local_integratable_id=helpdesk_tickets.id", 
            :conditions=>["integrated_resources.remote_integratable_id=?", "{{issue.key}}"]}
          }
        },
        :map=>[
          {:ours=>"status", :theirs_to_ours=>{:handler=>:map_field, :value=>"{{issue.fields.status.name}}", :mapping_values=>{
                      "Resolved"=>RESOLVED,
                      "Closed"=>CLOSED,
                      "Default" => OPEN,
                      "In Progress" => PENDING}
                    }},
          {:ours=>"disable_observer", :theirs_to_ours=>{:handler=>:static_value, :value=>true}}
        ], 
        :update=>{:theirs_to_ours_handler=>:db_save}
      },
      :add_comment_in_jira => {:map => [{:ours_to_theirs=>{:value=>"Note added by {{helpdesk_note.commenter.name}} in Freshdesk:\n {{helpdesk_note.body_text}}\n"}}]},
      :add_status_as_comment_in_jira => {:map => [{:ours_to_theirs=>{:value=>"Freshdesk ticket status changed to : {{helpdesk_ticket.status}}"}}]},
      :update_jira_status => {:map => [{:ours_to_theirs=>{:handler=>:map_field, :value=>"{{helpdesk_ticket.status}}", :mapping_values=>{
                      "Default"=>"Reopen Issue",
                      "Resolved"=>"Resolve Issue",
                      "Closed"=>"Close Issue",
                      "Pending" => "Start Progress"}
                    }}]}
    }

  HANDLERS = {
    :db_fetch=>{
      :clazz=>"Integrations::Mapper::DBHandler",
      :method=>:fetch
    },
    :hash_fetch=>{
      :clazz=>"Integrations::Mapper::HashHandler",
      :method=>:fetch
    },
    :db_save=>{
      :clazz=>"Integrations::Mapper::DBHandler",
      :method=>:save
    },
    :template_convert=>{
      :clazz=>"Integrations::Mapper::GenericMapper",
      :method=>:template_convert
    },
    :map_field=>{
      :clazz=>"Integrations::Mapper::GenericMapper",
      :method=>:map_field
    },
    :static_value=>{
      :clazz=>"Integrations::Mapper::GenericMapper",
      :method=>:static_value
    }
  }
end


#             {:theirs=>"status", :ours=>"status", 
#                     :theirs_to_ours_mapping=>{
#                       "Default"=>OPEN,
#                       "Resolved"=>RESOLVED,
#                       "Closed"=>CLOSED
#                     }
#             }, {:theirs=>"priority", :ours=>"priority", 
#                     :theirs_to_ours_mapping=>{
#                       "Default"=>PRIORITY_KEYS_BY_TOKEN[:low],
#                       "Blocker"=>PRIORITY_KEYS_BY_TOKEN[:urgent],
#                       "Critical"=>PRIORITY_KEYS_BY_TOKEN[:high],
#                       "Major"=>PRIORITY_KEYS_BY_TOKEN[:high],
#                       "Minor"=>PRIORITY_KEYS_BY_TOKEN[:medium],
#                       "Trivial"=>PRIORITY_KEYS_BY_TOKEN[:low]
#                     }
#             }, {:theirs=>"status", :ours=>"body", 
#                     :theirs_to_ours_mapping=>{
#                       "Default"=>OPEN,
#                       "Resolved"=>RESOLVED,
#                       "Closed"=>CLOSED
#                     }
