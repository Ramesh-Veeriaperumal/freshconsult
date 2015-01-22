#encoding: utf-8

module Search::KeywordSearch::Ticket

  ES_DEFAULT_FIELDS = {
    :analyzed => [], #Should probably add type alone here and/or tags, or we can have it as not_analyzed
    :not_analyzed => ["status", "priority", "source", "group_id", "requester_id", "responder_id"]
  }

  def keyword_search_queries b
    (es_fields[:analyzed] & params[:search_conditions].keys).each do |search_key|
      search_value = params[:search_conditions][search_key]

      b.must do |multi_match_block|
        multi_match_block.boolean do |mm_bool|
          search_value.each do |mm_value|
            mm_bool.should { match search_key.to_sym, mm_value, :type => :phrase }
          end
        end
      end
    end
  end

  def keyword_search_filters
    filter_array = []

    (es_fields[:not_analyzed] & params[:search_conditions].keys).each do |search_key|
      search_value = params[:search_conditions][search_key]
      filter_array << { :terms => { search_key => search_value } }
    end
    
    filter_array
  end

  private

  def es_fields
    @@es_fields ||= begin { 
        :analyzed     => ES_DEFAULT_FIELDS[:analyzed] + (flexifield_analyzed_columns),
        :not_analyzed => ES_DEFAULT_FIELDS[:not_analyzed] + (flexifield_not_analyzed_columns) 
      }
    end
  end

  def flexifield_analyzed_columns
    Flexifield.column_names.inject([]){ |res, col| res << "flexifield.#{col}" if col =~ /^ff(s|_text)/ ; res }
  end

  def flexifield_not_analyzed_columns
    Flexifield.column_names.inject([]){ |res, col| res << "flexifield.#{col}" if col =~ /^ff(_int|_decimal)/ ; res }
  end

end