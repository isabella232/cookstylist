require "mixlib/log"
require "mixlib/config" unless defined?(Mixlib::Config)
require_relative "cookstylist/corrector"
require_relative "cookstylist/github"
require_relative "cookstylist/installation"
require_relative "cookstylist/worker"
require_relative "cookstylist/periodic"
require_relative "cookstylist/pullrequest"
require_relative "cookstylist/reactor"
require_relative "cookstylist/repo"
require_relative "cookstylist/worker"

module Cookstylist
  class Log
    extend Mixlib::Log
  end

  module Config
    extend Mixlib::Config

    default :log_level, :info
  end
end