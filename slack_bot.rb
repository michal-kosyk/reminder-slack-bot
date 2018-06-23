require 'slack-ruby-bot'
require 'bunny'
require 'json'

STDOUT.sync = true

class MyView < SlackRubyBot::MVC::View::Base; end
class MyModel < SlackRubyBot::MVC::Model::Base; end

class MyController < SlackRubyBot::MVC::Controller::Base
  USER_REGEXP = /remind (.*) that/
  ACTIVITY_REGEXP = /that (.*)/

  def remind
    message = data["text"]
    user = user_name(message)
    activity = activity_name(message)
    set_reminder(user, activity)
    client.say(channel: data.channel, text: "Reminder sent")
  end

  private

  def user_name(message)
    message.match(USER_REGEXP).captures[0]
  end

  def activity_name(message)
    message.match(ACTIVITY_REGEXP).captures[0]
  end

  def bunny_conn
    @bunny_conn ||= Bunny.new
  end

  def set_reminder(user, activity)
    bunny_conn.start
    ch = bunny_conn.create_channel
    q  = ch.queue("slackbot.raw_messages")
    x  = ch.default_exchange

    x.publish(json_msg(user, activity), :routing_key => q.name)
  end

  def json_msg(user, activity)
    { message: activity, user: user }.to_json
  end
end

class SlackBot < SlackRubyBot::Bot
  view = MyView.new
  model = MyModel.new
  @controller = MyController.new(model, view)
  @controller.class.command_class.routes.each do |route|
    STDERR.puts route.inspect
  end
end

SlackBot.run
