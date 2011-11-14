class Settings
  include Mongoid::Document

  # Fields
  field :name, :type => String
  field :value, :type => String
  key :name

  # Validations

  # Scopes

  # Helpers
  def self::get name
    setting = self::find_or_create_by(name: name)
    setting.value
  end

  def self::set name, value
    setting = self::find_or_create_by(name: name)
    setting.value = value
    setting.save
  end
end
