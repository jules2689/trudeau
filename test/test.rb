
require "bundler/inline"

gemfile do
  source 'https://rubygems.org'
  gem "nokogiri"
  gem "activesupport"
  gem "spellchecker"
  gem "rspec"
end

require "yaml"
require_relative "../lib/caption_parser"
require 'rspec/autorun'

ENV["TEST"] = '1'

describe Trudeau::CaptionParser do
  let(:raw_captions) { File.read(File.expand_path("../captions.xml", __FILE__)) }
  subject do
    s = Trudeau::CaptionParser.new(raw_captions)
    s.parse
    s
  end

  it "parses the right number of rows" do
    expect(subject.dialog[:pre_news].size).to eq(33)
    expect(subject.dialog[:trudeau].size).to eq(10)
    expect(subject.dialog[:q_a].size).to eq(54)
    expect(subject.dialog[:post_news].size).to eq(57)
  end

  it "parses trudeau's speech" do
    trudeau = subject.dialog[:trudeau]

    YAML.load_file(File.expand_path("../expected_trudeau.yml", __FILE__)).each_with_index do |entry, idx|
      expect(trudeau[idx].speaker).to eq(entry['speaker'])
      expect(trudeau[idx].msg).to eq(entry['message'].chomp)

      expect(trudeau[idx].duration.to_f).to be_within(0.1).of(entry['duration'])
      expect(trudeau[idx].starting_time.to_f).to be_within(0.1).of(entry['starting_time'])
    end
  end
end