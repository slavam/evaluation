# coding: utf-8
class BlocksController < ApplicationController
#  before_filter :find_block, :only => [:show, :edit, :update, :destroy]
  before_filter :find_direction, :only => [:new_block, :edit_weights]
  before_filter :find_blocks, :only => [:new_block, :edit_weights]
  def index
    @blocks = Block.all
  end
  
  def show
  end

  def new_block
    @block = Block.new
  end
  
  def save_weights
    total_weight = 0
    if params[:new_block][:weight] == ''
      flash_error :weight_is_empty
      redirect_to :action => 'new_block', :direction_id => params[:direction_id]
      return
    end
    if params[:w]
      params[:w].keys.each  do |id|
        total_weight += params[:w][id.to_s][:weight].to_f
      end
    end  
    total_weight += params[:new_block][:weight].to_f
    if total_weight>1
      flash_error :weight_is_wrong
      redirect_to :action => 'new_block', :direction_id => params[:direction_id]
    else 
      @blocks = Block.where("direction_id=?",  params[:direction_id])
      if @blocks.size>0
        @blocks.collect { |b|
        if params[:w][b.id.to_s][:weight].to_f >= 0
          @block_weight = BlockWeight.new
          @block_weight.block_id = b.id
          @block_weight.start_date = Time.now
          @block_weight.weight = params[:w][b.id.to_s][:weight]
          @block_weight.description = params[:new_block][:description]
          @block_weight.save
        end  
        }
      end
      @block = Block.new
      @block.direction_id = params[:direction_id]
      @block.block_description_id = params[:new_block][:block_description_id]
      @block.save
      @block_weight = BlockWeight.new
      @block_weight.block_id = @block.id
      @block_weight.weight = params[:new_block][:weight]
      @block_weight.start_date = Time.now
      @block_weight.description = params[:new_block][:description]
      @block_weight.save
      redirect_to :controller => 'directions', :action => 'show_eigen_blocks', :id => params[:direction_id]
    end
  end
  
  def create
    @block = Block.new params[:block]
    if not @block.save
      render :new
    else
      redirect_to :blocks
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
      redirect_to :action => 'edit_weights', :direction_id => params[:direction_id]
    else 
      @blocks = Block.where("direction_id=?",  params[:direction_id])
      if @blocks.size>0
        @blocks.collect { |b|
          @block_weight = BlockWeight.new
          @block_weight.block_id = b.id
          @block_weight.start_date = Time.now
          @block_weight.weight = params[:w][b.id.to_s][:weight]
          @block_weight.description = params[:w][b.id.to_s][:description]
          @block_weight.save
        }
      end
      redirect_to :controller => 'directions', :action => 'show_eigen_blocks', :id => params[:direction_id]
    end
  end
  
  def update
    if not @block.update_attributes params[:block]
      render :action => :edit
    else
      redirect_to block_path(@block)
    end
  end
  
  def destroy
    @block.destroy
    redirect_to blocks_path
  end
  private
  
  def find_block
    if params[:id]
      @block = Block.find params[:id]
    else
      @block = Block.find params[:block][:id]
    end
  end
  
  def find_direction
    @direction = Direction.find params[:direction_id]  
  end
  
  def find_blocks
    @blocks = Block.where("direction_id=?",  params[:direction_id])
  end
end