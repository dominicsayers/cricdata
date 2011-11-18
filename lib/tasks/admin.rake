require 'net/http'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch

desc "These tasks are run manually for admin purposes"

task :mark_all_players_dirty => :environment do
    dputs 'Marking all players as dirty...'

    Player.all.each do |player|
      player.dirty = true
dputs player.inspect # debug
      player.save
    end

    dputs 'done.'
end

task :mark_indeterminate_players_dirty => :environment do
    dputs 'Marking all indeterminate players as dirty...'

    Player.indeterminate.each do |player|
      player.dirty = true
dputs player.inspect # debug
      player.save
    end

    dputs 'done.'
end

task :update_player, [:player_ref] => [:environment] do |t, args|
    player_ref = (args.player_ref || "0")
    dputs "Parsing #{player_ref}..."
    Player.update player_ref
    dputs 'done.'
end

task :mark_all_matches_unparsed => :environment do
    dputs 'Marking all matches as unparsed...'
    Match.mark_all_unparsed
    dputs 'done.'
end

task :parse_match, [:match_ref] => [:environment] do |t, args|
    match_ref = (args.match_ref || "0")
    dputs "Parsing #{match_ref}..."
    Match.parse match_ref
    dputs 'done.'
end
