# A sample Guardfile
# More info at https://github.com/guard/guard#readme

## Uncomment and set this to only include directories you want to watch
directories %w(lib spec) \
 .select{|d| Dir.exist?(d) ? d : UI.warning("Directory #{d} does not exist")}

 guard :rspec, cmd: 'bundle exec rspec' do
   watch(%r{^spec/.+_spec\.rb$})
   watch('spec/spec_helper.rb')                        { 'spec' }
   watch(%r{^lib/(.+)\.rb$})                           { |m| "spec/lib/#{m[1]}_spec.rb" }
 end


## Note: if you are using the `directories` clause above and you are not
## watching the project directory ('.'), then you will want to move
## the Guardfile to a watched dir and symlink it back, e.g.
#
#  $ mkdir config
#  $ mv Guardfile config/
#  $ ln -s config/Guardfile .
#
# and, you'll have to watch "config/Guardfile" instead of "Guardfile"
