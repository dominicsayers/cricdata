require 'net/http'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch

desc "These tasks are called by the Heroku scheduler add-on"

task :new_matches => :environment do
    dputs "Scraping new matches..."
    Search.new_matches
    dputs "done."
end

task :parse_next_match => :environment do
    dputs "Parsing first unparsed match..."
    Match.parse_next
    dputs "done."
end

task :parse_all_matches => :environment do
    dputs "Parsing all unparsed matches..."
    Match.parse_all
    dputs "done."
end

task :update_dirty_players => :environment do
    dputs "Updating players' statistics..."
    Player.update_dirty_players
    dputs "done."
end
