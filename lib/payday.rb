# frozen_string_literal: true

require 'zeitwerk'
loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.setup

require 'active_support/core_ext/object/blank' # For Object#blank? method
require 'bigdecimal'
require 'date'
require 'money'
require 'prawn'
require 'prawn/table'
require 'prawn-svg'
require 'time'

# Load translations from the locale folder
I18n.enforce_available_locales = false
I18n.load_path.concat(Dir[File.join('lib', 'payday', 'locale', '*.yml')])
