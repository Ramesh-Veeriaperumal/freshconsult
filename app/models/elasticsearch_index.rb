class ElasticsearchIndex < ActiveRecord::Base

  include Tire::Model::Search if ES_ENABLED
  include MemcacheKeys
  include ErrorHandle

  has_many :es_enabled_accounts, :class_name => 'EsEnabledAccount', :foreign_key => "index_id"

  after_commit_on_create :create_search_index

  def self.es_id_for(account_id)
    search_shard_delta = 0
    search_shard = (account_id % 50) + 1 + search_shard_delta
    es_index = find_by_id(search_shard)
    es_index.id
  end

  def create_search_index
    sandbox(0) {
      Tire.index(self.name) do
        create(
          :settings => {
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
          :mappings => {
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
                  :deleted => { :type => :boolean, :include_in_all => false }
              }
            },
            :customer => {
              :properties => {
                  :name => { :type => :string, :boost => 10, :store => 'yes' },
                  :description => { :type => :string, :boost => 3 },
                  :note => { :type => :string, :boost => 4 },
                  :account_id => { :type => :long, :include_in_all => false }
              }
            },
            :"helpdesk/ticket" => {
              :properties => {
                :display_id => { :type => :long, :store => 'yes' },
                :subject => { :type => :string, :boost => 10, :store => 'yes' },
                :description => { :type => :string, :boost => 5, :store => 'yes' },
                :account_id => { :type => :long, :include_in_all => false },
                :responder_id => { :type => :long, :null_value => 0, :include_in_all => false },
                :group_id => { :type => :long, :null_value => 0, :include_in_all => false },
                :requester_id => { :type => :long, :include_in_all => false },
                :status => { :type => :long, :include_in_all => false },
                :spam => { :type => :boolean, :include_in_all => false },
                :deleted => { :type => :boolean, :include_in_all => false },
                :attachments => { :type => "object", 
                                  :properties => {
                                    :content_file_name => { :type => :string } 
                                  }
                                },
                :es_notes => { :type => "object", 
                               :properties => {
                                 :body => { :type => :string },
                                 :private => { :type => :boolean, :include_in_all => false },
                                 :attachments => { :type => :string }
                               }
                             },
                :es_from => { :type => :string },
                :to_emails => { :type => :string },
                :es_cc_emails => { :type => :string },
                :es_fwd_emails => { :type => :string },
                :company_id => { :type => :long, :null_value => 0, :include_in_all => false }
              }
            },
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
                                }
              }
            },
            :topic => {
              :properties => {
                  :title => { :type => :string, :boost => 10, :store => 'yes' },
                  :user_id => { :type => :long, :include_in_all => false },
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
                            }
              }
            }
          }
        )
      end
    }
  end
end
