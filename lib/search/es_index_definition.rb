class Search::EsIndexDefinition

  CLUSTER_ARR = [DEFAULT_CLUSTER = "fd_es_index_1", "fd_es_index_2"]

	class << self
		include ErrorHandle

  # These are table names of the searchable models.
  # Incase we want to add any new model the table name should be added here
  def models
    [:customers, :users, :helpdesk_tickets, :solution_articles, :topics, :helpdesk_notes, :helpdesk_tags, :freshfone_callers]
  end

  # Used for new model migrations
  def additional_models
    []
  end

  def index_hash(pre_fix = DEFAULT_CLUSTER, is_additional_model=false)
    index_models = is_additional_model ? additional_models : models
    Hash[*index_models.map { |i| [i,"#{i}_#{pre_fix}"] }.flatten]
  end

	def create_es_index(index_name = DEFAULT_CLUSTER, is_additional_model=false)
    index_hash(index_name, is_additional_model).each do |key, value|
      create_model_index(value, key)
    end
	end

	def customers
    	{
        	:customer => {
              :properties => {
                  :name => { :type => :string, :boost => 10, :store => 'yes' },
                  :description => { :type => :string, :boost => 3 },
                  :note => { :type => :string, :boost => 4 },
                  :account_id => { :type => :long, :include_in_all => false },
                  :created_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                  :updated_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false }
              }
            }
  		}
	end

	def users
    	{
        	:user => {
              :properties => {
                  :name => { :type => :string, :boost => 10, :store => 'yes' },
                  :email => { :type => :string, :boost => 50 },
                  :description => { :type => :string, :boost => 3 },
                  :job_title => { :type => :string, :boost => 4, :store => 'yes' },
                  :phone => { :type => :string },
                  :mobile => { :type => :string },
                  :customer => { :type => "object", 
                                 :properties => {
                                   :name => { :type => :string, :boost => 5, :store => 'yes' } 
                                 }
                               },
                  :twitter_id => { :type => :string },
                  :fb_profile_id => { :type => :string },
                  :account_id => { :type => :long, :include_in_all => false },
                  :deleted => { :type => :boolean, :include_in_all => false },
                  :helpdesk_agent => { :type => :boolean, :include_in_all => false },
                  :created_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                  :updated_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false }
              }
            }
  		}
	end

  def helpdesk_tags
    {
          :"helpdesk/tag" => {
              :properties => {
                :name => { :type => :string, :boost => 5, :store => 'yes' },
                :tag_uses_count => { :type => :long, :include_in_all => false },
                :account_id => { :type => :long, :include_in_all => false }
              }
            }
      }
  end

	def helpdesk_tickets
    	{
        	:"helpdesk/ticket" => {
              :properties => {
                :display_id => { :type => :long },
                :subject => { :type => :string, :boost => 10, :store => 'yes' },
                :description => { :type => :string, :boost => 5, :store => 'yes' },
                :account_id => { :type => :long, :include_in_all => false },
                :responder_id => { :type => :long, :null_value => 0, :include_in_all => false },
                :group_id => { :type => :long, :null_value => 0, :include_in_all => false },
                :requester_id => { :type => :long, :include_in_all => false },
                :status => { :type => :long, :include_in_all => false },
                :spam => { :type => :boolean, :include_in_all => false },
                :deleted => { :type => :boolean, :include_in_all => false },
                :source => { :type => :long, :include_in_all => false },
                :priority => { :type => :long, :include_in_all => false },
                :due_by => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                :attachments => { :type => "object", 
                                  :properties => {
                                    :content_file_name => { :type => :string } 
                                  }
                                },
                :ticket_states => { :type => "object", 
                                    :properties => {
                                      :resolved_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                                      :closed_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                                      :agent_responded_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                                      :requester_responded_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                                      :status_updated_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                                  }
                                },
                :es_from => { :type => :string },
                :to_emails => { :type => :string },
                :es_cc_emails => { :type => :string },
                :es_fwd_emails => { :type => :string },
                :company_id => { :type => :long, :null_value => 0, :include_in_all => false },
                :created_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                :updated_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false }

              }
            }
  		}
	end

  def helpdesk_notes
      {
          :"helpdesk/note" => {
              :properties => {
                :body => { :type => :string, :boost => 5, :store => 'yes' },
                :account_id => { :type => :long, :include_in_all => false },
                :notable_id => { :type => :long, :include_in_all => false },
                :notable_requester_id => { :type => :long, :include_in_all => false },
                :notable_responder_id => { :type => :long, :null_value => 0, :include_in_all => false },
                :notable_group_id => { :type => :long, :null_value => 0, :include_in_all => false },
                :notable_spam => { :type => :boolean, :include_in_all => false },
                :deleted => { :type => :boolean, :include_in_all => false },
                :private => { :type => :boolean, :include_in_all => false },
                :notable_deleted => { :type => :boolean, :include_in_all => false },
                :attachments => { :type => "object", 
                                  :properties => {
                                    :content_file_name => { :type => :string } 
                                  }
                                },
                :notable_company_id => { :type => :long, :null_value => 0, :include_in_all => false },
                :created_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                :updated_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false }
              }
            }
      }
  end

	def solution_articles
    	{
        	:"solution/article" => {
              :properties => {
                :title => { :type => :string, :boost => 10, :store => 'yes' },
                :desc_un_html => { :type => :string, :boost => 6, :store => 'yes' },
                :tags => { :type => "object", 
                           :properties => {
                             :name => { :type => :string } 
                           }
                         },
                :user_id => { :type => :long, :include_in_all => false },
                :folder_id => { :type => :long, :include_in_all => false },
                :status => { :type => :integer, :include_in_all => false },
                :account_id => { :type => :long, :include_in_all => false },
                :folder => { :type => "object", 
                             :properties => { 
                               :category_id => { :type => :long, :include_in_all => false },
                               :visibility => { :type => :long, :include_in_all => false },
                               :customer_folders => { :type => "object",
                                                      :properties => {
                                                        :customer_id => { :type => :long, :include_in_all => false }  
                                                      }
                                                    }
                             }
                           },
                :attachments => { :type => "object", 
                                  :properties => {
                                    :content_file_name => { :type => :string } 
                                  }
                                },
                :created_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                :updated_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false }
              }
            }
  		}
	end

	def topics
    	{
        	:topic => {
              :properties => {
                  :title => { :type => :string, :boost => 10, :store => 'yes' },
                  :user_id => { :type => :long, :include_in_all => false },
                  :forum_id => { :type => :long, :include_in_all => false },
                  :posts => { :type => "object", 
                              :properties => {
                                :body => { :type => :string, :boost => 4, :store => 'yes' },
                                :attachments => { :type => "object", 
                                                  :properties => {
                                                    :content_file_name => { :type => :string } 
                                                  }
                                                }
                              }
                            },
                  :account_id => { :type => :long, :include_in_all => false },
                  :forum => { :type => "object", 
                              :properties => {
                                :forum_category_id => { :type => :long, :include_in_all => false },
                                :forum_visibility => { :type => :integer, :include_in_all => false },
                                :customer_forums => { :type => "object",
                                                       :properties => {
                                                         :customer_id => { :type => :long, :include_in_all => false }  
                                                       }
                                                     }
                              }
                            },
                  :created_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false },
                  :updated_at => { :type => :date, :format => 'dateOptionalTime', :include_in_all => false }
              }
            }
  		}
	end

  def freshfone_callers 
    {
      :"freshfone/caller" => {
        :properties => {
            :number => { :type => :string, :boost => 10, :store => 'yes' },
            :account_id => { :type => :long, :include_in_all => false }
        }
      }
    }
  end

  def create_model_index(index_name, model_mapping)
  	sandbox(0) {
      Search::EsIndexDefinition.es_cluster_by_prefix(index_name)
      Tire.index(index_name) do
        create(
          :settings => {
            :number_of_shards => 15,
            :number_of_replicas => 1,
            :analysis => {
              :filter => {
                :word_filter  => {
                       "type" => "word_delimiter",
                       "split_on_numerics" => false,
                       "generate_word_parts" => false,
                       "generate_number_parts" => false,
                       "split_on_case_change" => false,
                       "preserve_original" => true
                }
              },
              :analyzer => {
                :default => { :type => "custom", :tokenizer => "whitespace", :filter => [ "word_filter", "lowercase" ] },
                :include_stop => { :type => "custom", :tokenizer => "whitespace", :filter => [ "word_filter", "lowercase", "stop" ] }
              }
            }
          },
          :mappings =>  Search::EsIndexDefinition.send(model_mapping.to_sym) 
        )
  	end
  }
  end

  # Will return an array of alias names for the classes provided
  # parameters: search_in (Array of class objects not just names) and account_id
  def searchable_aliases(search_in, account_id)
    res_aliases = []
    search_in.each do |klass|
      res_aliases << "#{klass.table_name}_#{account_id}"
    end
    res_aliases
  end
  
  def create_aliases(account_id, is_additional_model=false)
    sandbox(0) {
      pre_fix = Search::EsIndexDefinition.es_cluster(account_id)
      actions = []
      index_hash(pre_fix, is_additional_model).each do |model, index_name|
        operation = { :index => index_name, :alias => "#{model}_#{account_id}" }
        operation.update( { :routing => account_id.to_s } )
        operation.update( { :filter  => { :term => { :account_id => account_id } } } )
        actions.push( { :add => operation } )
      end
      add_actions = { :actions => actions }
      response = Tire::Configuration.client.post "#{Tire::Configuration.url}/_aliases", add_actions.to_json
      result = JSON.parse(response.body)
      result["ok"] || NewRelic::Agent.notice_error(result["error"])
    }
  end

  def remove_aliases(account_id, is_additional_model=false)
    sandbox(0) {
      pre_fix = Search::EsIndexDefinition.es_cluster(account_id)
      actions = []
      index_hash(pre_fix, is_additional_model).each do |model, index_name|
        a = Tire::Alias.find("#{model}_#{account_id}")
        operation = { :index => index_name, :alias => a.name }
        actions.push( { :remove => operation } )
      end
      add_actions = { :actions => actions }
      response = Tire::Configuration.client.post "#{Tire::Configuration.url}/_aliases", add_actions.to_json
      result = JSON.parse(response.body)
      result["ok"] || NewRelic::Agent.notice_error(result["error"])
    }
  end

  def rebalance_aliases(account_id,new_index_prefix,old_index_prefix = DEFAULT_CLUSTER, is_additional_model=false)
    sandbox(0) {
      Search::EsIndexDefinition.es_cluster(account_id)
      old_index_hash = index_hash(old_index_prefix, is_additional_model)
      index_hash(new_index_prefix, is_additional_model, is_additional_model).each do |model, index_name|
        a = Tire::Alias.find("#{model}_#{account_id}")
        a.indices.add index_name
        a.indices.delete old_index_hash[model]
        a.routing(account_id.to_s)
        a = a.save
        response  = JSON.parse(a.body)
        NewRelic::Agent.notice_error(response["error"])  unless response["ok"]
      end
    }
  end

  def es_cluster(account_id)
    index = (account_id <= 55000) ? 0 : 1
    Tire.configure { url Es_aws_urls[index] }
    CLUSTER_ARR[index]
  end

  def es_cluster_by_prefix(index_prefix)
    CLUSTER_ARR.each_with_index do |prefix,i|
      return Tire.configure { url Es_aws_urls[i] } if index_prefix.include? prefix
    end
  end

end
end