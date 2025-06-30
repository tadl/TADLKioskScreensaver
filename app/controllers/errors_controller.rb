# app/controllers/errors_controller.rb
class ErrorsController < ApplicationController
  layout false  # or use your landing layout if you have one

  # note: :code comes from the route default
  def show
    code = params[:code].to_i

    # You can grab the exception if you want more detail:
    exception = request.env["action_dispatch.exception"]
    @message   = exception&.message.presence || Rack::Utils::HTTP_STATUS_CODES[code]
    @code      = code

    # render app/views/errors/show.html.erb
    render :show, status: code
  end
end
