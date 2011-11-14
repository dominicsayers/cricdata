require 'net/http'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch

desc "This task is called by the Heroku scheduler add-on"

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
