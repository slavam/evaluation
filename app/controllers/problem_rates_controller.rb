# coding: utf-8
class ProblemRatesController < ApplicationController
  before_filter :find_factor, :only => [:index, :new_interval, :create]
  def index
    @rates = ProblemRate.where('factor_id=?', @factor.id).order(:begin_value)
  end
  
  def delete_interval
    interval = ProblemRate.find params[:problem_rate_id]
    factor_id = interval.factor_id
    interval.destroy
    redirect_to problem_rates_path :factor_id => factor_id
  end

  def edit
    @interval = ProblemRate.find params[:id]
    @factor = Factor.find @interval.factor_id
  end

  def update
    @interval = ProblemRate.find params[:id]
    if not @interval.update_attributes params[:problem_rate]
      render :action => :edit
    else
      notice_updated
      redirect_to problem_rates_path :factor_id => @interval.factor_id
    end
  end
  
  def new_interval
    @interval = ProblemRate.new
  end
  
  def create
    @interval = ProblemRate.new params[:problem_rate]
    @interval.factor_id = @factor.id
    @interval.direction_id = @factor.block.direction_id
    @interval.start_date = Time.now
    if not @interval.save
      render :new_interval
    else
      notice_updated
      redirect_to problem_rates_path :factor_id => @factor.id
    end
  end

  private
  
  def find_factor
    @factor = Factor.find params[:factor_id]
  end
end