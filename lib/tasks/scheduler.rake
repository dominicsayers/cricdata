require 'net/http'
require "#{Rails.root.join('app/helpers/console_log')}"
require "#{Rails.root.join('app/helpers/fetch')}"

include ConsoleLog
include Fetch

namespace :regular do
  desc 'Add any new matchers since the last run'
  task new_matches: :environment do
    dputs 'Scraping new matches...'
    Search.new_matches
    dputs 'done.'
  end

  desc 'Get data for the next unparsed match'
  task parse_next_match: :environment do
    dputs 'Parsing first unparsed match...'
    Match.parse_next
    dputs 'done.'
  end

  desc 'Get data for all unparsed matches'
  task parse_all_matches: :environment do
    dputs 'Parsing all unparsed matches...'
    Match.parse_all
    dputs 'done.'
  end

  desc 'Update statistics for all players with recent performances'
  task update_dirty_players: :environment do
    dputs "Updating players' statistics..."
    MatchTypePlayer.update_dirty_players
    dputs 'done.'
  end
end
