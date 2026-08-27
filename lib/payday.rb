# frozen_string_literal: true

require 'zeitwerk'
loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.setup

require 'active_support/core_ext/object/blank' # For Object#blank? method
require 'bigdecimal'
require 'date'
require 'json'
require 'money'
require 'typst'
require 'time'

# Load our own translations. This has to resolve against the gem rather than the working
# directory, or the locales only load when the process happens to be running from the gem root.
I18n.load_path.concat(Dir[File.expand_path('../config/locales/*.yml', __dir__)])

module Payday
end
