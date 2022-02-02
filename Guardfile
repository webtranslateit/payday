 guard :rspec, cmd: 'bundle exec rspec --color --format progress' do
   watch(%r{^spec/.+_spec\.rb$})
   watch('spec/spec_helper.rb')                        { 'spec' }
   watch(%r{^lib/(.+)\.rb$})                           { |m| "spec/lib/#{m[1]}_spec.rb" }
 end

 guard :rubocop do
   watch(/.+\.rb$/)
   watch(%r{(?:.+/)?\.rubocop(?:_todo)?\.yml$}) { |m| File.dirname(m[0]) }
 end
