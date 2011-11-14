class Inning
  include Mongoid::Document

  # Fields
#-  field :match_id, :type => Integer
  field :inning_number, :type => Integer
  field :extras, :type => Integer
  field :extras_analysis, :type => String
  field :summary, :type => String

  key :match_id, :inning_number

  # Validations

  # Scopes

  # Relationships
  belongs_to :match
  has_many :performances

  # Helpers
end
