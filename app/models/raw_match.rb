# Raw match HTML from the source
class RawMatch
  include Mongoid::Document

  # Fields
  field :match_ref, :type => Integer
  field :html,      :type => String
  field :zhtml,     :type => Moped::BSON::Binary

#  key :match_ref
  index({ match_ref:1 }, { unique:true })
end
