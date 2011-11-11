# coding: utf-8
class ParamDescriptionsController < ApplicationController
  def index
    @params = ParamDescription.order(:id)
  end
  def new
    @param_description = ParamDescription.new
  end
  
  def create
    @param_description = ParamDescription.new params[:param_description]
    if not @param_description.save
      render :new
    else
      redirect_to param_descriptions_path
    end
  end
  
end