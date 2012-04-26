# coding: utf-8
class FactorsController < ApplicationController
  before_filter :find_block, :only => [:new_factor, :save_weights, :edit_weights, :save_updated_weights, :save_factor, :add_weights]
  before_filter :find_factor, :only => [:edit_descriptor, :save_descriptor, :destroy_factor]
  
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
 
  def save_factor
    @factor = Factor.new
    @factor.block_id = params[:block_id]
    @factor.factor_description_id = params[:new_factor][:factor_description_id]
    @factor.plan_descriptor = params[:new_factor][:plan_descriptor]
    @factor.fact_descriptor = params[:new_factor][:fact_descriptor]
    @factor.save
    f_w = FactorWeight.new
    f_w.factor_id = @factor.id
    f_w.start_date = Time.now
    f_w.weight = 0
    f_w.save    
    redirect_to :controller => 'directions', :action => 'show_factors', :id => params[:block_id]
  end
  
  def add_weights
  end

  def save_weights
    total_weight = 0
    if params[:w]
      params[:w].keys.each  do |id|
        total_weight += params[:w][id.to_s][:weight].to_f
      end
    end
    total_weight += params[:new_factor][:weight].to_f
    if (total_weight-1).abs>0.00001
      flash_error :weight_is_wrong
      redirect_to :action => 'new_factor', :block_id => params[:block_id]
    else 
      if @block.categorization
        @factors = @block.factors.where("div_category_id = ?", params[:category_id])
      else
        @factors = @block.factors
      end  
      if @factors.size>0
        @factors.collect { |f|
          @factor_weight = FactorWeight.new
          @factor_weight.factor_id = f.id
          @factor_weight.start_date = Time.now
          @factor_weight.weight = params[:w][f.id.to_s][:weight]
          @factor_weight.description = params[:new_factor][:description]
          @factor_weight.save
        }
      end
      @factor = Factor.new
      @factor.block_id = params[:block_id]
      @factor.factor_description_id = params[:new_factor][:factor_description_id]
      @factor.plan_descriptor = params[:new_factor][:plan_descriptor]
      @factor.fact_descriptor = params[:new_factor][:fact_descriptor]
      if @block.categorization
        @factor.div_category_id = params[:category_id]        
      end
      @factor.save
      @factor_weight = FactorWeight.new
      @factor_weight.factor_id = @factor.id
      @factor_weight.weight = params[:new_factor][:weight]
      @factor_weight.start_date = Time.now
      @factor_weight.description = params[:new_factor][:description]
      @factor_weight.save
      if @block.categorization
        redirect_to :controller => 'directions', :action => 'show_eigen_factors', :id => params[:block_id], :category => {:category_id => params[:category_id]}
      else
        redirect_to :controller => 'directions', :action => 'show_eigen_factors', :id => params[:block_id]
      end  
    end
  end
  
  def edit_weights
    @category = CategoryOfDivision.find params[:category][:category_id] if @block.categorization
  end
  
  def save_updated_weights
    total_weight = 0.0
    params[:w].keys.each  do |id|
      total_weight += (params[:w][id.to_s][:weight].to_f*100).round / 100
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
          @factor_weight.weight = (params[:w][f.id.to_s][:weight].to_s > '0' ? params[:w][f.id.to_s][:weight] : 0)
          @factor_weight.description = params[:w][f.id.to_s][:description]
          if @block.categorization
            @factor_weight.division_category_id = params[:category_id]
          end
          @factor_weight.save
        }
      end
      redirect_to :controller => 'directions', :action => 'show_factors', :id => params[:block_id]
    end
  end
 
  def edit_descriptor
  end
  
  def update
    @factor = Factor.find params[:id]
    if not @factor.update_attributes params[:factor]
      render :action => :edit_descriptor
    else
      notice_updated
      redirect_to :controller => 'directions', :action => 'show_articles', :id => @factor
    end
  end
  
  def destroy_factor
    block_id = @factor.block_id
    @factor.factor_weights.each {|w| w.destroy}
    @factor.destroy
    redirect_to :controller => 'directions', :action => 'show_factors', :id => block_id
  end
 
  private
  
  def find_factor
    @factor = Factor.find params[:id]
  end
  
  def find_block
    @block = Block.find params[:block_id]
  end  
end