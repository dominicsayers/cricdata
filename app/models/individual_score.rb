class IndividualScore
  include Mongoid::Document

  # Fields
  field :type_number,               :type => Integer
  field :runs,                      :type => Integer
  field :date_start,                :type => Date
  field :name,                      :type => String
  field :latest_date,               :type => Date
  field :latest_name,               :type => String
  field :unscored,                  :type => Boolean
  field :current_lowest_unscored,   :type => Boolean
  field :has_been_lowest_unscored,  :type => Boolean
  field :has_been_highest_score,    :type => Boolean

  key :type_number, :runs

  # Indexes
  index([ [:type_number, Mongo::ASCENDING], [:runs, Mongo::ASCENDING] ], unique: true)

  # Relationships
  belongs_to :player
  belongs_to :inning

  # Scopes
  default_scope asc(:type_number).desc(:runs)

  # Helpers
  # Register an individual score
  def self::register inning, match_type_player, runs, date_start
$\ = ' ' # debug

    type_number = match_type_player.type_number
    score_max   = self.where(type_number:type_number).asc(:runs).last

    if score_max.blank?
      # Seed the collection
      score_max                           = self.find_or_create_by type_number:type_number, runs:0
      score_max.unscored                  = true
      score_max.current_lowest_unscored   = true
      score_max.has_been_lowest_unscored  = true
      score_max.save
    end

    max_runs    = score_max.runs
dprint max_runs, :cyan # debug

    if runs > max_runs
      # Fill in any gaps
      while runs > max_runs
        max_runs += 1
        score = self.find_or_create_by type_number:type_number, runs:max_runs

        if score.unscored.blank?
          score.unscored                    = true
          score.save
        end
  dprint max_runs, :pink # debug
      end

      score.has_been_highest_score = true
      score.save
    end
dputs ' ' # debug

    score           = self.find_or_create_by type_number:type_number, runs:runs
    score.unscored  = false # that's a given

    # Is this an earlier (or the first) performance?
    if score.date_start.blank? or date_start < score.date_start
      score.inning      = inning
      score.player      = match_type_player.player
      score.name        = match_type_player.name
      score.date_start  = date_start
    end

    # Is this a later (or the last) performance?
    if score.latest_date.blank? or date_start > score.latest_date
      score.latest_name  = match_type_player.name
      score.latest_date  = date_start
    end

    # Is this the current lowest unscored score?
    if score.current_lowest_unscored == true
      score.current_lowest_unscored = false
      score.save

      # Now look for the next lowest
      lu = self.where(type_number:type_number, unscored:true).asc(:runs).first

      if lu.blank? # All scores might have been scored
        # Add a score 1 higher than the current highest score
        lu_runs = self.where(type_number:type_number).max(:runs) + 1
        lu_runs = runs + 1 if lu_runs.blank?
        lu      = self.find_or_create_by type_number:type_number, runs:lu_runs
      end

      lu.unscored                  = true
      lu.current_lowest_unscored   = true
      lu.has_been_lowest_unscored  = true
      lu.save
dp lu # debug
    end

    # Save it
    score.save
dp score # debug
  end
end
