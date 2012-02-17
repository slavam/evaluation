# coding: utf-8
class ValuesController < ApplicationController
  before_filter :find_factor, :only => [:add_data_by_division, :add_data_by_worker, :show_values_by_factor]

  def get_values_params
    @factors = Factor.find_by_sql("select f.id id, fd.short_name f_name, d.short_name d_name from factors f join factor_descriptions fd on fd.id=f.factor_description_id join blocks b on b.id=f.block_id join directions d on d.id=b.direction_id where plan_descriptor = 'get_plan_from_values' or fact_descriptor = 'get_fact_from_values' and b.block_description_id not in (2, 3) order by d.id, fd.id ")  
  end
  
  def new_data
    @v = Value.new
    @factor = Factor.find params[:data_params][:factor_id]    
    @period = Period.find params[:data_params][:period_id]
    case @factor.block.direction.level_id
      when 3
        @divisions = BranchOfBank.where("open_date is not null").order(:code)
      when 2 # all regions 
        @divisions = BranchOfBank.where("open_date is not null and parent_id = 1 and id != 40").order(:code)
        
    end  
     
  end
  
  def save_data
    @factor = Factor.find params[:factor_id]    
    @period = Period.find params[:period_id]
    is_data = false
    params[:value].each {|k, v|
      if v[:factor_value] > ''
        value = Value.new
        value.create_date = Time.now
        value.period_id = @period.id
        value.factor_id = @factor.id
        value.division_id = k[3,k.length-3].to_i
        if @factor.plan_descriptor == 'get_plan_from_values' and k[0] == '1'
          value.type_id = 1
          value.factor_value = v[:factor_value].to_f
          value.save
          is_data = true
        end
        if @factor.fact_descriptor == 'get_fact_from_values' and k[0] == '2'
          value.type_id = 2
          value.factor_value = v[:factor_value].to_f
          value.save
          is_data = true
        end
      end
    }  
    if is_data
      flash_notice 'added'
    end
    redirect_to :action => 'get_values_params' 
  end
  
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
      @value.fullname = w.lastname+' '+w.firstname+' '+w.soname
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