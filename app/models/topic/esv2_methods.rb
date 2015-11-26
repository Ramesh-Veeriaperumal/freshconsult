class Topic < ActiveRecord::Base

  def to_esv2_json
    as_json({
        root: false,
        tailored_json: true,
        only: [ :forum_id, :user_id, :title, :created_at, 
                :updated_at, :hits, :locked, :account_id, 
                :stamp_type, :user_votes, :published ],
        methods: [ :forum_category_id, :forum_visibility, :company_ids ]
      }).to_json
  end

  def forum_category_id
    forum.forum_category_id
  end

  def forum_visibility
    forum.forum_visibility
  end

  def company_ids
    forum.customer_forums.map(&:customer_id)
  end

  ##########################
  ### V1 Cluster methods ###
  ##########################
  
  # _Note_: Will be deprecated and remove in near future
  #
  def to_indexed_json
    as_json(
          :root => "topic",
          :tailored_json => true,
          :only => [ :title, :user_id, :forum_id, :account_id, :created_at, :updated_at ],
          :include => { :posts => { :only => [:body],
                                    :include => { :attachments => { :only => [:content_file_name] } }
                                  },
                        :forum => { :only => [:forum_category_id, :forum_visibility],
                                    :include => { :customer_forums => { :only => [:customer_id] } }
                                  }
                      }
       ).to_json
  end
end