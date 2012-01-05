class IndividualScore
  include Mongoid::Document

  # Fields
  field :type_number,               :type => Integer
  field :runs,                      :type => Integer
  field :date_start,                :type => Date
  field :name,                      :type => String
  field :match_ref,                 :type => String
  field :current_lowest_unscored,   :type => Boolean
  field :has_been_lowest_unscored,  :type => Boolean

  key :type_number, :runs

  # Indexes
  index([ [:type_number, Mongo::ASCENDING], [:runs, Mongo::ASCENDING] ], unique: true)

  # Relationships
  belongs_to :match_type_player
  belongs_to :inning
end
