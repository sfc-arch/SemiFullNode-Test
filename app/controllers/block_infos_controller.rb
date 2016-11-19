class BlockInfosController < ApplicationController
  enable_sync

  before_action :set_block_info, only: [:show, :edit, :update, :destroy]

  def index
    @block_infos = BlockInfo.all.order(:height).reverse
    @block_info_all = BlockInfo.all

    respond_to do |format|
      # sync_update @block_infos
      format.html # index
      format.js { render json: @block_infos }
    end
  end

  def new
    @block_info = BlockInfo.new
  end

  def destroy
    @block_info.destroy
    # respond_to do |format|
    #   format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
    #   format.json { head :no_content }
    # end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_block_info
    @block_info = BlockInfo.find(params[:id])
  end
end
