require "bundler/inline"

gemfile do
  source 'https://rubygems.org'
  gem "cli-kit"
end

_, stat = CLI::Kit::System.capture2e("which aspell")
unless stat.success?
  puts "aspell must be installed"
end

base_path = File.expand_path("../trudeau/", __FILE__)

day = CLI::UI.ask("Which day do you want to spellcheck?", options: Dir.glob(File.join(base_path, "*")).sort.reverse)
Dir.glob(File.join(day, "*.md")).each do |file|
  puts file
  system("aspell --mode=markdown check --dont-backup #{file}")
end
