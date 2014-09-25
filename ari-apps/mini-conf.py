#!/usr/bin/env python

import ari
import logging
import thread
import sys
import random
import requests
import json
from irc.bot import SingleServerIRCBot

logging.basicConfig(level=logging.ERROR)

class IRCBot(SingleServerIRCBot):
    def __init__(self, nickname, server, port=6667):
        SingleServerIRCBot.__init__(self, [(server, port)], nickname, nickname)
        self.channel = '#asterisk-testing'

    def send_chan_msg(self, msg):
        self.connection.privmsg(self.channel, msg)

    def on_nicknameinuse(self, c, e):
        c.nick(c.get_nickname() + "_")

    def on_welcome(self, c, e):
        # c.privmsg("NickServ", "identify %s " % botconfig.PASS)
        # time.sleep(5)
        c.join(self.channel)

    def on_privmsg(self, c, e):
        self.do_command(e, e.arguments[0])
        self.__process_event(c, e, privmsg=True)

    def on_action(self, c, e):
        self.__process_event(c, e)

    def on_pubmsg(self, c, e):
        a = e.arguments[0].split(":", 1)
        # if len(a) > 1 and irc_lower(a[0]) == irc_lower(self.connection.get_nickname()):
        #    self.do_command(e, a[1].strip())
        self.__process_event(c, e)

    def __process_event(self, c, e, privmsg=False):
        if privmsg:
            return_to = e.source
        else:
            return_to = e.target
        conn = self.connection
        msg = '\n'.join(e.arguments)
        print "%s: %s" % (e.source, msg)

        return

    def on_dccmsg(self, c, e):
        c.privmsg("You said: " + e.arguments[0])

    def do_command(self, e, cmd):
        nick = e.source
        channel = e.target
        c = self.connection

        if 'monkey' in cmd:
            monkey_time()
        elif 'call' in cmd:
            uri = cmd.replace('call', '').strip()
            place_call(uri)


client = ari.connect('http://neutron.jcn-labs.net:8088', 'vuc-conf', 'digiumtacos')
#client = ari.connect('http://localhost:8088', 'asterisk', 'asterisk')

channel_count = 0
channels = []

irc_bot = IRCBot('vuc_asterisk_bot', 'chat.freenode.net')

conf_bridge = None
try:
    conf_bridge = client.bridges.get(bridgeId='vuc')
except:
    pass

if not conf_bridge:
    conf_bridge = client.bridges.create(type='mixing,dtmf_events', bridgeId='vuc', name='vuc')

for bridge_channel in conf_bridge.json.get('channels'):
    existing_channel = client.channels.get(channelId=bridge_channel)
    channels.append(existing_channel)
    print "%s is already waiting in the bridge" % existing_channel.json.get('name')

def place_call(uri):

    client.channels.originate(endpoint='Local/s@outbound', app='vuc-conf', variables={'__OUTBOUND_CHANNEL': uri})
    irc_bot.send_chan_msg('Placing call to %s' % uri)

def monkey_time():

    if len(channels) == 0:
        print "No one is available for monkeys :-("
        return

    unlucky = random.randint(0, len(channels) - 1)
    channel = channels[unlucky]
    print "%s: It's monkey time!" % format_channel_name(channel)
    irc_bot.send_chan_msg("%s: It's monkey time!" % format_channel_name(channel))

    def on_monkeys_done(playback, ev):
        try:
            conf_bridge.addChannel(channel=channel.id)
            channels.append(channel)
        except:
            pass

    channels.remove(channel)
    conf_bridge.removeChannel(channel=channel.id)
    monkeys = channel.play(media='sound:tt-monkeys')
    monkeys.on_event('PlaybackFinished', on_monkeys_done)


def format_channel_name(channel):
    full_name = None
    try:
        full_name = channel.getChannelVar(variable='conf_name').get('value')
    except:
        pass

    if not full_name:
        try:
            ip_addr = channel.getChannelVar(variable='CHANNEL(pjsip,remote_addr)').get('value')
            ip_addr = ip_addr[:ip_addr.index(':')]
            loc = requests.get('http://freegeoip.net/json/%s' % ip_addr).json()

            city = loc.get('city', '')
            region = loc.get('region_name', '')
            country = loc.get('country_name', '')

            full_loc = '%s%s%s%s%s' % (
                city,
                ', ' if len(city) > 0 else '',
                region,
                ', ' if len(region) > 0 else '',
                country)
            full_name = ('Channel (%s from %s)' % (channel.json.get('name'), full_loc))
            channel.setChannelVar(variable='conf_name', value=full_name)
        except:
            full_name = channel.json.get('name')
    return full_name


def stasis_start_cb(channel_obj, ev, channel_count):
    channel = channel_obj.get('channel')
    channel_count += 1

    def stasis_end_cb(channel, ev, channel_count):
        channel_count -= 1
        print "%s left the conference" % format_channel_name(channel)
        irc_bot.send_chan_msg("%s left the conference" % format_channel_name(channel))
        try:
            channels.remove(channel)
        except:
            pass
        if (channel_count == 1):
            conf_bridge.play(media='sound:conf-onlypersonleft')

    def on_dtmf_received(channel, ev):
        digit = int(ev.get('digit'))
        if digit == 0:
            print '%s has decided someone gets the monkeys...' % format_channel_name(channel)
            monkey_time()

    def notify_conference(playback, ev):
        conf_bridge.addChannel(channel=channel.id)
        channels.append(channel)
        print '%s joined the conference' % format_channel_name(channel)
        irc_bot.send_chan_msg('%s joined the conference' % format_channel_name(channel))
        channel.on_event('ChannelDtmfReceived', on_dtmf_received)

        conf_bridge.play(media='sound:beep')

    channel_announce = channel.play(media='sound:conf-placeintoconf')
    channel_announce.on_event('PlaybackFinished', notify_conference)

    channel.answer()
    channel.on_event('StasisEnd', stasis_end_cb, channel_count)
    return

client.on_channel_event('StasisStart', stasis_start_cb, channel_count)

def run():
    """Run the websocket!"""
    print 'Starting the Websocket'
    client.run(apps='vuc-conf')
    print 'Websocket thread returned'

def run_irc():
    """Connect the IRC bot"""
    print 'Kicking off the IRC bot'
    irc_bot.start()

thr = thread.start_new_thread(run, ())
irc_thread = thread.start_new_thread(run_irc, ())

print "Type 'exit' to quit"
continue_loop = True
while continue_loop:
    sys.stdout.write('>> ')
    command = sys.stdin.readline().rstrip()
    if command == 'exit':
        client.close()
        irc_bot.die()
        continue_loop = False
    elif command == 'monkey':
        monkey_time()
    elif command == 'who':
        for channel in channels:
            print "%s is hanging out" % format_channel_name(channel)

print "Should be done now..."

