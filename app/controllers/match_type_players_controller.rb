class MatchTypePlayersController < ApplicationController
  # GET /players/xfactor
  # GET /players/xfactor.json
	def xfactor
		@mtps = MatchTypePlayer.xfactory

    respond_to do |format|
      format.html # xfactor.html.erb
      format.json { render json: @mtps }
    end
	end

	def xfactorodi
		@mtps = MatchTypePlayer.xfactoryodi

		render 'xfactor'
	end
end
