# frozen_string_literal: true

require 'bundler'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

# Gives us build, install and release.
Bundler::GemHelper.install_tasks

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]
