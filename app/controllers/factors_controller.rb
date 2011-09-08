# coding: utf-8
class FactorsController < ApplicationController
  before_filter :find_block, :only => [:new_factor, :save_weights, :edit_weights, :save_updated_weights]
  
  def show
  end

  def show_factors_by_template
    @factors = Factor.find_by_sql("SELECT f.*, wf.weight factor_weight, wf.business_plan_article article FROM factors f
      JOIN weight_factors wf ON f.id=wf.factor_id AND wf.template_id ="+params[:template_id]+
      ' order by wf.template_id, f.block_id')
  end

  def show_values
    @values = @factor.performances.order(:calc_date)  
  end
  
  def new_factor
    @factor = Factor.new
  end
  
  def save_weights
    total_weight = 0
    if params[:w]
      params[:w].keys.each  do |id|
        total_weight += params[:w][id.to_s][:weight].to_f
      end
    end
    total_weight += params[:new_factor][:weight].to_f
    if total_weight>1
      flash_error :weight_is_wrong
      redirect_to :action => 'new_factor', :block_id => params[:block_id]
    else 
      @factors = @block.factors
      if @factors.size>0
        @factors.collect { |f|
          @factor_weight = FactorWeight.new
          @factor_weight.factor_id = f.id
          @factor_weight.start_date = Time.now
          @factor_weight.weight = params[:w][f.id.to_s][:weight]
          @factor_weight.description = params[:new_block][:description]
          @factor_weight.save
        }
      end
      @factor = Factor.new
      @factor.block_id = params[:block_id]
      @factor.factor_description_id = params[:new_factor][:factor_description_id]
      @factor.save
      @factor_weight = FactorWeight.new
      @factor_weight.factor_id = @factor.id
      @factor_weight.weight = params[:new_factor][:weight]
      @factor_weight.start_date = Time.now
      @factor_weight.description = params[:new_block][:description]
      @factor_weight.save
      redirect_to :controller => 'directions', :action => 'show_eigen_factors', :id => params[:block_id]
    end
  end
  
  def edit_weights
  end
  
  def save_updated_weights
    total_weight = 0
    params[:w].keys.each  do |id|
      total_weight += params[:w][id.to_s][:weight].to_f
    end
    if total_weight>1
      flash_error :weight_is_wrong
      redirect_to :action => 'edit_weights', :block_id => params[:block_id]
    else 
      @factors = @block.factors
      if @factors.size>0
        @factors.collect { |f|
          @factor_weight = FactorWeight.new
          @factor_weight.factor_id = f.id
          @factor_weight.start_date = Time.now
          @factor_weight.weight = params[:w][f.id.to_s][:weight]
          @factor_weight.description = params[:w][f.id.to_s][:description]
          @factor_weight.save
        }
      end
      redirect_to :controller => 'directions', :action => 'show_eigen_factors', :id => params[:block_id]
    end
  end
  
  def destroy
    @factor.destroy
    redirect_to factors_path
  end
 
  private
  
  def find_factor
    @factor = Factor.find params[:id]
  end
  
  def find_block
    @block = Block.find params[:block_id]
  end  
end