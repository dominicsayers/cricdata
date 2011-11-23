class PlayersController < ApplicationController
	def xfactor
		@players = Player.xfactory
	end

	def xfactorodi
		@players = Player.xfactoryodi

		render 'xfactor'
	end
end
