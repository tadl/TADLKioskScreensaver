class KiosksController < ApplicationController
  before_action :set_kiosk, only: %i[ show edit update destroy ]

  # GET /kiosks or /kiosks.json
  def index
    @kiosks = Kiosk.all
  end

  # GET /kiosks/1 or /kiosks/1.json
  def show
  end

  # GET /kiosks/new
  def new
    @kiosk = Kiosk.new
  end

  # GET /kiosks/1/edit
  def edit
  end

  # POST /kiosks or /kiosks.json
  def create
    @kiosk = Kiosk.new(kiosk_params)

    respond_to do |format|
      if @kiosk.save
        format.html { redirect_to @kiosk, notice: "Kiosk was successfully created." }
        format.json { render :show, status: :created, location: @kiosk }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @kiosk.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /kiosks/1 or /kiosks/1.json
  def update
    respond_to do |format|
      if @kiosk.update(kiosk_params)
        format.html { redirect_to @kiosk, notice: "Kiosk was successfully updated." }
        format.json { render :show, status: :ok, location: @kiosk }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @kiosk.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /kiosks/1 or /kiosks/1.json
  def destroy
    @kiosk.destroy!

    respond_to do |format|
      format.html { redirect_to kiosks_path, status: :see_other, notice: "Kiosk was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_kiosk
      @kiosk = Kiosk.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def kiosk_params
      params.require(:kiosk).permit(:name, :slug, :catalog_url)
    end
end
