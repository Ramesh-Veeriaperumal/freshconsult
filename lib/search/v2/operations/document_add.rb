# Class to add document insert/updates to ES
#
class Search::V2::Operations::DocumentAdd

  def initialize(args)
    args.symbolize_keys!

    @klass      = args.delete(:klass_name)
    @type       = args.delete(:type)
    @account_id = args.delete(:account_id)
    @doc_id     = args.delete(:document_id)
    @timestamps = args.delete(:timestamps)
    @params     = args
  end

  def perform
    entity = @klass.constantize.find_by_account_id_and_id(@account_id, @doc_id)

    if entity
      # All dates to be stored in UTC
      #
      Time.use_zone('UTC') do
        if entity.is_a?(Solution::Article) && Account.current.es_multilang_solutions_enabled?
          locale = entity.solution_folder_meta.solution_category_meta.portals.last.try(:language)
          locale = SearchService::Utils.valid_locale([@type], locale)
          SearchService::Client.new(@account_id).write_object(entity, @params[:version], @params[:parent_id], @type, locale)
        else
          SearchService::Client.new(@account_id).write_object(entity, @params[:version], @params[:parent_id], @type)
        end
      end
    end
  end
end