require 'net/http'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch

desc "These tasks are run manually for admin purposes"

task :mark_all_players_dirty => :environment do
    dputs "Marking all players as dirty..."
    Player.mark_all_dirty
    dputs "done."
end
