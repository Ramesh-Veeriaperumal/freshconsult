module Solution::ArticleFilterScoper
  extend ActiveSupport::Concern

  included do
    scope :by_status, lambda { |status_data|
      status = status_data[:status].to_i
      if status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
        where(status: status)
      elsif status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
        { 
          :joins => %(INNER JOIN solution_drafts ON solution_drafts.article_id = solution_articles.id AND 
                      solution_articles.account_id = solution_drafts.account_id AND 
                      solution_articles.account_id = %{account_id}) % {  
                      account_id: Account.current.id },
          :conditions => status_condition_hash(status_data)
        }
      end
    }

    scope :by_category, lambda { |category_ids|
      {
        :joins => %(AND solution_articles.account_id = solution_article_meta.account_id
                    AND solution_folder_meta.account_id = solution_article_meta.account_id AND 
                    solution_articles.account_id = %{account_id}) % { account_id: Account.current.id },
        :conditions => ["solution_folder_meta.solution_category_meta_id IN (?)", category_ids]
      }
    }

    scope :by_folder, lambda { |folder_ids|
      {
        :joins => %(AND solution_article_meta.account_id = solution_articles.account_id AND 
                    solution_articles.account_id = %{account_id}) % { account_id: Account.current.id },
        :conditions => ["solution_article_meta.solution_folder_meta_id IN (?)", folder_ids]
      } 
    }

    scope :by_tags, lambda { |tag_names|
      {
        :joins => %(INNER JOIN helpdesk_tag_uses ON helpdesk_tag_uses.taggable_id = solution_articles.id AND 
                    helpdesk_tag_uses.taggable_type = 'Solution::Article' AND
                    solution_articles.account_id = helpdesk_tag_uses.account_id
                    INNER JOIN helpdesk_tags ON helpdesk_tags.id = helpdesk_tag_uses.tag_id AND
                    helpdesk_tag_uses.account_id = helpdesk_tags.account_id AND
                    solution_articles.account_id = %{account_id}) % { account_id: Account.current.id },
        :conditions => ["helpdesk_tags.name IN (?)", tag_names] 
      }
    }

    scope :by_created_at, lambda { |start_date, end_date|
      where(
        'solution_articles.created_at >= ? AND solution_articles.created_at <=?',
        DateTime.parse(start_date),
        DateTime.parse(end_date)
      )
    }

    scope :by_last_modified, lambda { |modified_at,modifier|
      case_operation = article_modified(modified_at,modifier)
      {
        :joins => %(JOIN (SELECT solution_articles.id article_id, #{case_operation} 
                      FROM solution_articles LEFT JOIN solution_drafts 
                      ON solution_drafts.article_id = solution_articles.id AND
                      solution_articles.account_id = solution_drafts.account_id AND 
                      solution_articles.account_id = %{account_id}
                    ) as article_modified on article_modified.article_id = solution_articles.id
                    LEFT JOIN solution_drafts 
                    ON solution_drafts.article_id = solution_articles.id AND
                    article_modified.article_id = solution_drafts.article_id AND
                    solution_articles.account_id = solution_drafts.account_id) % {  
                    account_id: Account.current.id },
        :conditions => @condition_list
      }
    }

    def self.article_modified modified_at, modifier
      @modified_at    = modified_at
      @modifier       = modifier
      @condition_list = [""]
      @modified_select_columns = ""
      
      last_modified_at if @modified_at.present?
      if @modifier.present?
        if @modified_select_columns.present?
          @modified_select_columns.concat(', ')
          @condition_list[0] = "#{@condition_list[0]} AND "
        end
        last_modifier
      end
      @modified_select_columns
    end

    def self.last_modified_at
      start_date = @modified_at['start']
      end_date   = @modified_at['end']
      @modified_select_columns.concat(%(
        CASE
          when solution_drafts.article_id is NULL
          then solution_articles.modified_at
          else solution_drafts.modified_at
        END as l_modified_at))
      @condition_list[0] = "#{@condition_list[0]} article_modified.l_modified_at between ? and ?"
      ["#{DateTime.parse(start_date)}", 
        "#{DateTime.parse(end_date)}"].each {|val| @condition_list << val}
    end

    def self.last_modifier
      @modified_select_columns.concat(%(
        CASE
          when solution_drafts.article_id is NULL 
          then solution_articles.modified_by
          else solution_drafts.user_id
        END as l_modifier))
      @condition_list[0] = %(#{@condition_list[0]} (solution_articles.user_id=%<user_id>i OR 
                                article_modified.l_modifier=%<user_id>i)) % { user_id: @modifier }
    end

    def self.status_condition_hash options
      conditions = [""]
      conditions[0] = %(#{conditions[0]} solution_drafts.user_id=%<user_id>i) % { user_id: 
                              options[:by_author] } if options[:by_author].present?
      if options[:by_last_modified_at].present?
        start_date    = options[:by_last_modified_at][:start]
        end_date      = options[:by_last_modified_at][:end]
        conditions[0] = "#{conditions[0]} AND " if conditions[0].present?
        conditions[0] = "#{conditions[0]} solution_drafts.modified_at between ? and ?"
        ["#{DateTime.parse(start_date)}", 
          "#{DateTime.parse(end_date)}"].each {|val| conditions << val}
      end
      conditions
    end
  end
end