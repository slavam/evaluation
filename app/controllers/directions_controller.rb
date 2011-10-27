# coding: utf-8
class DirectionsController < ApplicationController
  before_filter :find_direction, :only => [:destroy, :edit, :update, :show_eigen_blocks]
  before_filter :find_block, :only => :show_eigen_factors
  before_filter :find_factor, :only => :show_articles
  def index
    @directions = Direction.order(:name)
  end

  def show_eigen_blocks
  end

  def show_eigen_factors
  end

  def show_articles
  end
  
  def new
    @direction = Direction.new
  end
  
  def create
    @direction = Direction.new params[:direction]
    @direction.level_id = params[:levels][:level_id]
    if not @direction.save
      render :new
    else
      redirect_to directions_path
    end
  end

  def edit
  end

  def update
    @direction.level_id = params[:levels][:level_id]
    if not @direction.update_attributes params[:direction]
      render :action => :edit
    else
      notice_updated
      redirect_to directions_path
    end
  end
  
  private
  
  def find_direction
    if params[:id]
      @direction = Direction.find params[:id]
    else
      @direction = Direction.find params[:direction][:id]
    end  
  end

  def find_block
    @block = Block.find params[:id]
  end
  
  def find_factor
    @factor = Factor.find params[:id]
  end
end