require 'digest/md5'
require 'yaml'
require_relative 'dbconnection'

module Timetable
  class Preset
    attr_reader :name

    def self.find(name)
      db = DatabaseConnection.new("presets")
      db.find("name" => name)
    end

    def initialize(course, yoe, year, modules = nil)
      @course = course
      @yoe = yoe
      @year = year
      @modules = modules.map { |mod| mod.to_s }

      @ignored = modules_ignored

      @name = get_preset_name
      save_to_database
    end

  private

    # Returns the modules that the user has chosen to ignore,
    # given the ones he's chosen to take
    def modules_ignored
      # If @modules is nil, we assume the user is not ignoring anything
      return [] if @modules.nil?

      mods = config("course_modules") || []
      mods = mods[@course] || []
      mods = mods[@year] || []
      # Convert everything to string to make sure we can compare
      # the elements to the ones in @modules, which are strings
      mods.map! { |mod| mod.to_s }

      # Return the set difference between all the modules for the
      # course, yoe pair and the modules chosen by the user
      ignored = mods - @modules
      ignored.sort
    end

    def get_preset_name
      return if @ignored.nil?
      salted = @course.to_s + @yoe.to_s + @ignored.join
      Digest::MD5.hexdigest(salted)[0,5]
    end

    # Checks whether the preset is already present in our MongoHQ
    # instance, and saves it to the database if it isn't
    def save_to_database
      return if @name.nil?

      db = DatabaseConnection.new("presets")
      # Only insert if the record doesn't exist already
      unless db.exists?("name" => @name)
        db.insert(
          "name"    =>  @name,
          "course"  =>  @course,
          "yoe"     =>  @yoe,
          "ignored" =>  @ignored
        )
      end
      db.close
    end

    def config(key)
      @config ||= YAML.load_file("config/modules.yml")
      @config[key]
    end
  end
end
