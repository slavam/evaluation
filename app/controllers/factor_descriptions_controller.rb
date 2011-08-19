# coding: utf-8
class FactorDescriptionsController < ApplicationController
  before_filter :find_factor, :only => [:edit, :update]  
  def index
    @factor_names = FactorDescription.order(:name)
  end
  
  def new
    @factor = FactorDescription.new
  end
  
  def create
    @factor = FactorDescription.new params[:factor_description]
    if not @factor.save
      render :new
    else
      redirect_to factor_descriptions_path
    end
  end
  
  def edit
  end
  
  def update
    if not @factor.update_attributes params[:factor_description]
      render :action => :edit
    else
      redirect_to factor_descriptions_path
    end   
  end
  private
  
  def find_factor
    @factor = FactorDescription.find params[:id]
  end
end