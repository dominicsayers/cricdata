# Raw match HTML from the source
class RawMatch
  include Mongoid::Document

  # Fields
  field :match_id, :type => Integer
  field :html, :type => String

  key :match_id
end
