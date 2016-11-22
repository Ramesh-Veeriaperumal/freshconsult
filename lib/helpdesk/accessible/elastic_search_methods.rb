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

    def es_users_conditions(user = User.current)
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

    def accessible_from_esv2(model_name, options, visible_options={}, sort_option = nil, folder_id = nil, id_data = nil, excluded_ids = nil, type_ids = [])
      query_options = {
        sort_option:  sort_option,
        folder_id:    folder_id,
        id_data:      id_data,
        excluded_ids: excluded_ids,
        type_ids:     type_ids,
        query_params: params
      }
      Search::V2::Count::AccessibleMethods.new(model_name, options, visible_options).es_request(query_options)
    end

    def ca_folders_from_esv2(model_name, options, visible_options)
      Search::V2::Count::AccessibleMethods.new(model_name, options, visible_options).ca_folders_es_request()
    end

    def accessible_from_es(model_name,options,visible_options={}, sort_option = nil, folder_id = nil, id_data = nil, excluded_ids = nil, type_ids = [])
      begin
        Search::EsIndexDefinition.es_cluster(current_account.id)
        es_alias = Search::EsIndexDefinition.searchable_aliases([model_name],current_account.id)
        return nil unless Tire.index(es_alias).exists?
        user_groups = es_user_groups
        search_text = params[:search_string]
        item = Tire.search Search::EsIndexDefinition.searchable_aliases([model_name], current_account.id), options do |search|
          search.query do |query|
            query.filtered do |f|
              f.query { |q| q.string "*#{search_text}*", :analyzer => "include_stop" } if search_text.present?
              f.filter :bool, :should => es_filter_query(user_groups,visible_options)
              f.filter :bool, :must => { :term => { :folder_id => folder_id } } if folder_id
              f.filter :bool, :must => { :ids => { :values => id_data }} if id_data
              f.filter :bool, :must_not => { :ids => { :values => excluded_ids }} if excluded_ids.present?
              f.filter :bool, :must => { :term => { :association_type => type_ids } } if type_ids.present?
            end
          end
          search.sort { |t| t.by(sort_option,'asc') } if sort_option
        end
        item.results.results
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        nil
      end
    end

    def ca_folders_from_es(model_name,options,visible_options={})
      begin
        Search::EsIndexDefinition.es_cluster(current_account.id)
        es_alias = Search::EsIndexDefinition.searchable_aliases([model_name],current_account.id)
        return nil unless Tire.index(es_alias).exists?
        user_groups = current_user.agent_groups.map(&:group_id)
        item = Tire.search Search::EsIndexDefinition.searchable_aliases([model_name], current_account.id), options do |search|
          search.query do |query|
            query.filtered do |f|
              f.filter :bool, :should => es_filter_query(user_groups,visible_options)
            end
          end
          search.facet "ca_folders" do |ft|
            ft.terms :folder_id, :size => options[:size]
          end
        end
        item.results.facets
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        nil
      end
    end

    def default_visiblity
      {:global_type => true, :user_type => true, :group_type => true}
    end

    def es_user_groups user = User.current
      user.agent_groups.map(&:group_id)
    end


end
