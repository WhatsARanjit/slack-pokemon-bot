#!/usr/bin/env ruby

require 'slack'
require 'net/http'
require 'uri'
require 'yaml'

def yaml(file_path)
  YAML.load_file(file_path)
  rescue Exception => err
    $stederr.puts "YAML invalid: #{file_path}"
    raise "#{err}"
end

# Moving user-specific data to yaml
@config            = yaml('config.yaml')
@channel           = @config['channel']  || '#pokemon'
@interval          = @config['interval'] || 15
@token             = @config['token']

@client  = Slack::Client.new token: @token
@done    = Array.new
@pokemon = yaml('pokemon.yaml')['pokemon']

def channel_id
  @client.channels_list['channels'].select { |hash| hash['name'] == 'pokemon' }.first['id']
end

def messages
  @client.channels_history(channel: channel_id)['messages'].first(5)
end

def user_messages
  messages.select { |m| m['type'] == 'message' and !m.key?('subtype') }
end

def match_messages
  matches = Array.new
  user_messages.each do |message|
    sentence = message['text'].downcase
    unless @done.include?(message['ts'])
      matches << sentence.match(Regexp.union(@pokemon)).to_a
    end
    @done << message['ts']
  end
  matches.flatten
end

def pokemon_roar(match)
  roar = {
    :channel  => @channel,
    :username => match,
    :icon_url => "https://raw.githubusercontent.com/msikma/pokesprite/master/icons/pokemon/regular/#{match}.png",
    :text     => "#{match.capitalize}!",
  } 
  @client.chat_postMessage(roar)
end

def do_it
  matches = match_messages
  if matches
    matches.each do |match|
      pokemon_roar(match)
    end
  end
end

while true do
  begin
    do_it
  rescue Exception => e
    puts e.message
    puts e.backtrace.inspect
  else
    sleep @interval
  end
  # Debugging
  #exit 0
end
