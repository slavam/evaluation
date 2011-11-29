# coding: utf-8
class ValuesController < ApplicationController
  before_filter :find_factor, :only => [:add_data_by_division, :add_data_by_worker, :show_values_by_factor]
  def index
    @values = Value.order(:period_id, :division_id, :factor_id, :type_id)
  end
  
  def show_values_by_factor
    @values = Value.where('factor_id=?', params[:factor_id]).order(:period_id, :division_id)
    
  end
  
  def new
    @value = Value.new
  end
  
  def create
    @value = Value.new params[:value]
    @value.create_date = Time.now
    if not @value.save
      render :new
    else
      redirect_to values_path
    end
  end
  
  def add_data_by_worker
    @value = Value.new
  end
  
  def add_data_by_division
    @value = Value.new
  end
  
  def save_value
    @value = Value.new params[:value]
    @value.create_date = Time.now
    @value.factor_id = params[:factor_id]
    if @value.worker_id
      w = Worker.select('code_division, lastname, firstname, soname').where('id_emp=?',@value.worker_id).first
      code_division = w.code_division[0,3]
      d = BranchOfBank.where("code = ?",code_division).first
      @value.division_id = d.id
      @value.fullname = w.lastname.to_utf+' '+w.firstname.to_utf+' '+w.soname.to_utf
    end
    @factor = Factor.find params[:factor_id]
    if params[:division_id]
      @value.division_id = 999
    end
    if not @value.save
      if @value.worker_id
        render :add_data_by_worker
      else  
        render :add_data_by_division
      end  
    else
      redirect_to :action => 'show_values_by_factor', :factor_id => @factor.id 
#      redirect_to :controller => :directions, :action => 'show_eigen_factors', :id => @factor.block_id
    end
  end
  
  def delete_value
    value = Value.find params[:value_id]
    factor_id = value.factor_id
    
    value.destroy
    redirect_to :action => :show_values_by_factor, :factor_id => factor_id
  end
  
  private
  
  def find_factor
    @factor = Factor.find params[:factor_id]
  end
end