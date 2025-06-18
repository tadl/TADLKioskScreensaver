# frozen_string_literal: true

class KiosksController < ApplicationController
  before_action :set_kiosk, only: %i[edit update destroy]

  def index
    @kiosks = Kiosk.all
  end

  def new
    @kiosk = Kiosk.new
  end

  def edit
  end

  def create
    @kiosk = Kiosk.new(kiosk_params)
    if @kiosk.save
      redirect_to kiosks_path, notice: "Kiosk was successfully created."
    else
      render :new
    end
  end

  def update
    if @kiosk.update(kiosk_params)
      redirect_to kiosks_path, notice: "Kiosk was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    @kiosk.destroy
    redirect_to kiosks_path, notice: "Kiosk was successfully destroyed."
  end

  private

  def set_kiosk
    @kiosk = Kiosk.find(params[:id])
  end

  def kiosk_params
    params.require(:kiosk).permit(
      :name,
      :slug,
      :catalog_url,
      :kiosk_group_id
    )
  end
end

