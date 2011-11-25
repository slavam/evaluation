# coding: utf-8
class ParamsController < ApplicationController
  before_filter :find_factor, :only => [:show_params_by_factor, :new_param]
  before_filter :find_action, :only => [:show_params_by_factor, :new_param]
  def show_params_by_factor
    @parameters = Param.where('factor_id=? and action_id=?', params[:factor_id], params[:action_id])
  end
  
  def new_param
    @parameter = Param.new
  end
  
  def save_param
    @parameter = Param.new params[:param]
    @parameter.action_id = params[:action_id]
    @parameter.factor_id = params[:factor_id]
    if not @parameter.save
      render :new_param
    else
      redirect_to :action => 'show_params_by_factor', :factor_id => params[:factor_id], :action_id => params[:action_id] 
    end
  end
  
  def destroy
    @parameter = Param.find params[:id]
    factor_id = @parameter.factor_id
    @parameter.destroy
    redirect_to :controller => 'directions', :action => 'show_articles', :id => factor_id 
  end
  
  def edit
    @parameter = Param.find params[:id]
  end

  def update
    @parameter = Param.find params[:id]
    if not @parameter.update_attributes params[:param]
      render :action => :edit
    else
      notice_updated
      redirect_to :controller => 'directions', :action => 'show_articles', :id => @parameter.factor_id
    end
  end
  
  private
  
  def find_factor
    @factor = Factor.find params[:factor_id]
  end
  
  def find_action
    @action = Action.find params[:action_id]
  end
end