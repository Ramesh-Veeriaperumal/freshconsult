class AddSignatureHtmlToAgents < ActiveRecord::Migration
  def self.up
  	add_column :agents, :signature_html, :text   
  end

  def self.down
  	remove_column :agents, :signature_html
  end
end
