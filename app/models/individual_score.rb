class IndividualScore
  include Mongoid::Document

  # Fields
  field :type_number,               :type => Integer
  field :runs,                      :type => Integer
  field :date_start,                :type => Date
  field :name,                      :type => String
  field :unscored,                  :type => Boolean
  field :current_lowest_unscored,   :type => Boolean
  field :has_been_lowest_unscored,  :type => Boolean
  field :has_been_highest_score,    :type => Boolean

  key :type_number, :runs

  # Indexes
  index([ [:type_number, Mongo::ASCENDING], [:runs, Mongo::ASCENDING] ], unique: true)

  # Relationships
  belongs_to :match_type_player
  belongs_to :inning

  # Helpers
#  # Return the lowest unscored number of runs
#  def self::lowest_unscored type_number=MatchType::TEST
#    type_scores = self.where type_number:type_number
#dputs type_scores.length # debug
#    in_scs = type_scores.where current_lowest_unscored:true
#dputs in_scs.length # debug
#
#    if in_scs.length == 0
#      in_sc                 = type_scores.max(:runs)
#      lowest_unscored_runs  = in_sc.blank? ? 0 : in_sc.runs + 1
#dp in_sc # debug
#      in_sc                 = self.find_or_create_by type_number:type_number, runs:lowest_unscored_runs
#
#      in_sc.current_lowest_unscored  = true
#      in_sc.has_been_lowest_unscored = true
#      in_sc.save
#    else
#      lowest_unscored_runs = in_scs.first.runs
#    end
#
#dputs lowest_unscored_runs # debug
#    lowest_unscored_runs
#  end

  # Register an individual score
  def self::register type_number, runs, date_start, name
$\ = ' ' # debug

dputs 'Registering'

    in_sc_max  = self.where(type_number:type_number).asc(:runs).last
dp in_sc_max # debug

    if in_sc_max.blank?
      # Seed the collection
      in_sc_max                           = self.find_or_create_by type_number:type_number, runs:0
      in_sc_max.unscored                  = true
      in_sc_max.current_lowest_unscored   = true
      in_sc_max.has_been_lowest_unscored  = true
      in_sc_max.save
    end

    max_runs    = in_sc_max.runs
dprint max_runs # debug

    if runs > max_runs
      # Fill in any gaps
      while runs > max_runs
        max_runs += 1
        in_sc = self.find_or_create_by type_number:type_number, runs:max_runs

        if in_sc.unscored.blank?
          in_sc.unscored                    = true
          in_sc.save
        end
  dprint max_runs, :pink # debug
      end

      in_sc.has_been_highest_score = true
      in_sc.save
    end
dputs ' ' # debug

    in_sc           = self.find_or_create_by type_number:type_number, runs:runs
    in_sc.unscored  = false # that's a given

    # Is this an earlier performance?
    if in_sc.date_start.blank? or date_start < in_sc.date_start
      in_sc.date_start  = date_start
      in_sc.name        = name
    end

    # Is this the current lowest unscored score?
    if in_sc.current_lowest_unscored == true
      in_sc.current_lowest_unscored = false
      in_sc.save

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
    in_sc.save
dp in_sc # debug
  end
end
