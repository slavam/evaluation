class AuditsController < ApplicationController
  before_filter :require_admin

  def index
    @audits = Audit.all(:include => :user, :order => "created_at DESC" )
  end

  def show
    @audit = Audit.find params[:id]
    @value_field_names = @audit.action == 'update' ? 
      ['Old Value', 'New Value'] : ['Value']
  end
end
