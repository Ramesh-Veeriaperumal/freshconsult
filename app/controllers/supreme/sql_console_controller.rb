class Supreme::SqlConsoleController < Fdadmin::DevopsMainController

  STATUS = {
    :success => 1,
    :failure => 0
  }
  around_filter :select_slave_shard , :only => :execute_query

  def execute_query
    begin
      sql_res = ActiveRecord::Base.connection.execute(params[:query])
      query_hash = {
        :result => sql_res,
        :selected_columns => sql_res.fields,
        :status => STATUS[:success]
      }
    rescue Exception => exc
      NewRelic::Agent.notice_error(exc)
      logger.error("SQL Console Exception ::: #{exc.message}")
      query_hash = {
        :result => exc.message,
        :status => STATUS[:failure]
      }
    end
    respond_to do |format|
      format.json do
        render :json => query_hash
      end
    end
  end

end