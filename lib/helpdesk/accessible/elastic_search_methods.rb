module Helpdesk::Accessible::ElasticSearchMethods
    SHARED_VISIBILITY = {
      :global_type => true, :user_type => false, :group_type => true
    }
    PERSONAL_VISIBILITY = {
      :global_type => false, :user_type => true, :group_type => false
    }
    GLOBAL_VISIBILITY = {
      :global_type => true, :user_type => true, :group_type => true
    }

    def es_group_accesses
      self.helpdesk_accessible.group_access_type? ? self.helpdesk_accessible.group_ids : []
    end

     def es_user_accesses
      self.helpdesk_accessible.user_access_type? ? self.helpdesk_accessible.user_ids : []
    end

    def es_access_type
      self.helpdesk_accessible.access_type
    end

    def es_global_conditions
      {
        :term => {:es_access_type =>  Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]}
      }
    end

    def es_users_conditions(user = current_user)
      {
        :bool => {
          :must => [
            {
              :term => {:es_access_type =>  Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]}
            },
            {
              :term => {:es_user_accesses => user.id}
            }
          ]
        }
      }
    end

    def es_group_conditions(user_groups)
      {
        :bool => {
          :must => [
            {
              :term  => {:es_access_type =>  Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]}
            },
            {
              :terms => {:es_group_accesses => user_groups}
            }
          ]
        }
      }
    end


    #This is a es filter query which returns an array of hash
    #It will be fed into "should" of es filter.
    #either of the three terms in array will be retured from ES
    def es_filter_query(user_groups,visible_options)
      permissions = []
      permissions << es_global_conditions if visible_options[:global_type]
      permissions << es_users_conditions if visible_options[:user_type]
      permissions << es_group_conditions(user_groups) if visible_options[:group_type]
      permissions
    end

    def accessible_from_es(model_name,options,visible_options={})
      begin
        es_alias = Search::EsIndexDefinition.searchable_aliases([model_name],current_account.id)
        return nil unless Tire.index(es_alias).exists?
        user_groups = current_user.agent_groups.map(&:group_id)
        search_text = params[:search_string]
        Search::EsIndexDefinition.es_cluster(current_account.id)
        item = Tire.search Search::EsIndexDefinition.searchable_aliases([model_name], current_account.id), options do |search|
          search.query do |query|
            query.filtered do |f|
              f.query { |q| q.string "*#{search_text}*", :analyzer => "include_stop" } if search_text.present?
              f.filter :bool, :should => es_filter_query(user_groups,visible_options)
            end
          end
        end
        item.results.results
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        nil
      end
    end

end
