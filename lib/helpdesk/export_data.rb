class Helpdesk::ExportData < Struct.new(:params)    
  extend Resque::AroundPerform   
  @queue = 'data_export_queue'   
    
  def self.perform(params)   
    Helpdesk::ExportDataWorker.new(params).perform   
  end    
      
end